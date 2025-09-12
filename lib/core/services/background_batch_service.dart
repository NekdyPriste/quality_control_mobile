import 'dart:io';
import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/batch_analysis.dart';
import '../models/quality_report.dart';
import '../models/comparison_result.dart';
import 'gemini_service.dart';

class BackgroundBatchService {
  static const String batchTaskIdentifier = 'batch_analysis_task';
  
  static void initialize() {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  }
  
  static Future<void> scheduleBatchAnalysis({
    required String jobId,
    required List<BatchPhotoPair> photoPairs,
    required Map<String, String> jobData,
  }) async {
    // Uložení úlohy do local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('batch_job_$jobId', jsonEncode({
      'id': jobId,
      'photoPairs': photoPairs.map((p) => {
        'id': p.id,
        'referenceImagePath': p.referenceImagePath,
        'partImagePath': p.partImagePath,
        'partType': p.partType.name,
        'partSerial': p.partSerial,
      }).toList(),
      'jobData': jobData,
      'status': 'scheduled',
      'createdAt': DateTime.now().toIso8601String(),
    }));
    
    // Naplánování background úlohy
    await Workmanager().registerOneOffTask(
      jobId,
      batchTaskIdentifier,
      inputData: {
        'jobId': jobId,
        'totalPairs': photoPairs.length,
      },
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }
  
  static Future<void> cancelBatchAnalysis(String jobId) async {
    await Workmanager().cancelByUniqueName(jobId);
    
    // Označit jako zrušeno
    final prefs = await SharedPreferences.getInstance();
    final jobDataStr = prefs.getString('batch_job_$jobId');
    if (jobDataStr != null) {
      final jobData = jsonDecode(jobDataStr);
      jobData['status'] = 'cancelled';
      await prefs.setString('batch_job_$jobId', jsonEncode(jobData));
    }
  }
  
  static Future<List<BatchAnalysisJob>> getBackgroundJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('batch_job_'));
    
    final jobs = <BatchAnalysisJob>[];
    for (final key in keys) {
      final jobDataStr = prefs.getString(key);
      if (jobDataStr != null) {
        try {
          final jobData = jsonDecode(jobDataStr);
          jobs.add(_parseJobFromData(jobData));
        } catch (e) {
          print('Chyba při parsování background úlohy: $e');
        }
      }
    }
    
    return jobs;
  }
  
  static BatchAnalysisJob _parseJobFromData(Map<String, dynamic> data) {
    final photoPairs = (data['photoPairs'] as List).map((p) => 
      BatchPhotoPair(
        id: p['id'],
        referenceImagePath: p['referenceImagePath'],
        partImagePath: p['partImagePath'],
        partType: PartType.values.firstWhere((t) => t.name == p['partType']),
        partSerial: p['partSerial'],
      )
    ).toList();
    
    return BatchAnalysisJob(
      id: data['id'],
      name: data['jobData']['name'] ?? 'Background úloha',
      photoPairs: photoPairs,
      status: _parseStatus(data['status'] ?? 'pending'),
      createdAt: DateTime.parse(data['createdAt']),
      totalPairs: photoPairs.length,
      operatorName: data['jobData']['operatorName'],
      productionLine: data['jobData']['productionLine'],
      batchNumber: data['jobData']['batchNumber'],
    );
  }
  
  static BatchStatus _parseStatus(String status) {
    switch (status) {
      case 'scheduled': return BatchStatus.pending;
      case 'running': return BatchStatus.processing;
      case 'completed': return BatchStatus.completed;
      case 'failed': return BatchStatus.failed;
      case 'cancelled': return BatchStatus.failed;
      default: return BatchStatus.pending;
    }
  }
}

// Globální callback pro background úlohy
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case BackgroundBatchService.batchTaskIdentifier:
        return await _executeBatchAnalysis(inputData!);
      default:
        return Future.value(true);
    }
  });
}

Future<bool> _executeBatchAnalysis(Map<String, dynamic> inputData) async {
  try {
    final jobId = inputData['jobId'] as String;
    final prefs = await SharedPreferences.getInstance();
    
    // Načtení úlohy z local storage
    final jobDataStr = prefs.getString('batch_job_$jobId');
    if (jobDataStr == null) {
      print('Background úloha $jobId nenalezena');
      return false;
    }
    
    final jobData = jsonDecode(jobDataStr);
    jobData['status'] = 'running';
    jobData['startedAt'] = DateTime.now().toIso8601String();
    await prefs.setString('batch_job_$jobId', jsonEncode(jobData));
    
    // Inicializace služeb
    final geminiService = GeminiService();
    final dbHelper = DatabaseHelper();
    
    final photoPairs = (jobData['photoPairs'] as List).map((p) => 
      BatchPhotoPair(
        id: p['id'],
        referenceImagePath: p['referenceImagePath'],
        partImagePath: p['partImagePath'],
        partType: PartType.values.firstWhere((t) => t.name == p['partType']),
        partSerial: p['partSerial'],
      )
    ).toList();
    
    int completedCount = 0;
    int passCount = 0;
    int failCount = 0;
    int warningCount = 0;
    
    // Zpracování každého páru
    for (int i = 0; i < photoPairs.length; i++) {
      final pair = photoPairs[i];
      
      try {
        // AI analýza
        final comparisonResult = await geminiService.analyzeImages(
          referenceImage: File(pair.referenceImagePath),
          partImage: File(pair.partImagePath),
          partType: pair.partType,
        );
        
        // Uložení výsledku do databáze
        await dbHelper.saveInspection(
          referenceImagePath: pair.referenceImagePath,
          partImagePath: pair.partImagePath,
          partType: pair.partType,
          comparisonResult: comparisonResult,
          operatorName: jobData['jobData']['operatorName'],
          productionLine: jobData['jobData']['productionLine'],
          batchNumber: jobData['jobData']['batchNumber'],
          partSerial: pair.partSerial,
        );
        
        // Aktualizace statistik
        switch (comparisonResult.overallQuality) {
          case QualityStatus.pass: passCount++; break;
          case QualityStatus.fail: failCount++; break;
          case QualityStatus.warning: warningCount++; break;
        }
        
        completedCount++;
        
        // Aktualizace progress
        jobData['completedCount'] = completedCount;
        jobData['passCount'] = passCount;
        jobData['failCount'] = failCount;
        jobData['warningCount'] = warningCount;
        await prefs.setString('batch_job_$jobId', jsonEncode(jobData));
        
        // Pauza mezi API voláními
        await Future.delayed(const Duration(milliseconds: 500));
        
      } catch (e) {
        print('Chyba při zpracování páru ${pair.id}: $e');
        // Pokračovat s dalším párem
      }
    }
    
    // Dokončení úlohy
    jobData['status'] = 'completed';
    jobData['completedAt'] = DateTime.now().toIso8601String();
    await prefs.setString('batch_job_$jobId', jsonEncode(jobData));
    
    // TODO: Odeslání notifikace o dokončení
    
    return true;
    
  } catch (e) {
    print('Chyba background batch analýzy: $e');
    return false;
  }
}