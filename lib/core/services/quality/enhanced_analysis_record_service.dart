import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/quality/enhanced_analysis_record.dart';
import '../../models/quality/image_quality_metrics.dart';
import '../../models/quality/enhanced_confidence_score.dart';
import '../../models/quality/action_recommendation.dart';
import '../../models/quality/analysis_feedback.dart';
import '../../models/quality_report.dart';
import '../../database/database_helper.dart';

final enhancedAnalysisRecordServiceProvider = Provider<EnhancedAnalysisRecordService>((ref) {
  return EnhancedAnalysisRecordService();
});

class EnhancedAnalysisRecordService {
  static const String _tableName = 'enhanced_analysis_records';
  static const int _maxRecordsInMemory = 50;

  Database? _database;

  /// Vytvoří nový analysis record
  Future<EnhancedAnalysisRecord> createAnalysisRecord({
    required String referenceImagePath,
    required String partImagePath,
    required String userId,
    Map<String, dynamic>? additionalContext,
  }) async {
    final record = EnhancedAnalysisRecord.createNew(
      referenceImagePath: referenceImagePath,
      partImagePath: partImagePath,
      userId: userId,
      additionalContext: additionalContext,
    );

    await _saveRecord(record);
    return record;
  }

  /// Aktualizuje record s quality analysis výsledky
  Future<EnhancedAnalysisRecord> updateWithQualityAnalysis({
    required String recordId,
    required ImageQualityMetrics referenceQuality,
    required ImageQualityMetrics partQuality,
  }) async {
    final record = await getRecord(recordId);
    if (record == null) {
      throw Exception('Analysis record not found: $recordId');
    }

    final updatedRecord = record.withQualityAnalysis(
      referenceQuality: referenceQuality,
      partQuality: partQuality,
    );

    await _saveRecord(updatedRecord);
    return updatedRecord;
  }

  /// Aktualizuje record s confidence score
  Future<EnhancedAnalysisRecord> updateWithConfidenceScore({
    required String recordId,
    required EnhancedConfidenceScore confidenceScore,
    ActionRecommendation? recommendation,
  }) async {
    final record = await getRecord(recordId);
    if (record == null) {
      throw Exception('Analysis record not found: $recordId');
    }

    final updatedRecord = record.withConfidenceScore(
      confidence: confidenceScore,
      actionRecommendation: recommendation,
    );

    await _saveRecord(updatedRecord);
    return updatedRecord;
  }

  /// Označí doporučení jako následované
  Future<EnhancedAnalysisRecord> markRecommendationFollowed(
    String recordId,
  ) async {
    final record = await getRecord(recordId);
    if (record == null) {
      throw Exception('Analysis record not found: $recordId');
    }

    final updatedRecord = record.withRecommendationFollowed();
    await _saveRecord(updatedRecord);
    return updatedRecord;
  }

  /// Aktualizuje record s AI analysis výsledky
  Future<EnhancedAnalysisRecord> updateWithAIAnalysisResult({
    required String recordId,
    required QualityReport result,
    required Duration processingTime,
    int? tokensUsed,
    double? estimatedCost,
  }) async {
    final record = await getRecord(recordId);
    if (record == null) {
      throw Exception('Analysis record not found: $recordId');
    }

    final updatedRecord = record.withAIAnalysisResult(
      result: result,
      processingTime: processingTime,
      tokensUsed: tokensUsed,
      estimatedCost: estimatedCost,
    );

    await _saveRecord(updatedRecord);
    return updatedRecord;
  }

  /// Přidá uživatelský feedback k record
  Future<EnhancedAnalysisRecord> updateWithUserFeedback({
    required String recordId,
    required AnalysisFeedback feedback,
  }) async {
    final record = await getRecord(recordId);
    if (record == null) {
      throw Exception('Analysis record not found: $recordId');
    }

    final updatedRecord = record.withUserFeedback(feedback);
    await _saveRecord(updatedRecord);
    return updatedRecord;
  }

  /// Uloží images do record
  Future<EnhancedAnalysisRecord> storeImagesInRecord({
    required String recordId,
    required File referenceImage,
    required File partImage,
    String? compressionLevel,
  }) async {
    final record = await getRecord(recordId);
    if (record == null) {
      throw Exception('Analysis record not found: $recordId');
    }

    // Load image data
    final referenceData = await referenceImage.readAsBytes();
    final partData = await partImage.readAsBytes();

    // Optionally compress images
    final compressedReferenceData = compressionLevel != null 
        ? await _compressImage(referenceData, compressionLevel)
        : referenceData;
    final compressedPartData = compressionLevel != null
        ? await _compressImage(partData, compressionLevel)
        : partData;

    final updatedRecord = record.withStoredImages(
      referenceImageData: compressedReferenceData,
      partImageData: compressedPartData,
      compressionLevel: compressionLevel,
    );

    await _saveRecord(updatedRecord);
    return updatedRecord;
  }

  /// Označí record jako failed s error message
  Future<EnhancedAnalysisRecord> markRecordAsFailed({
    required String recordId,
    required String error,
  }) async {
    final record = await getRecord(recordId);
    if (record == null) {
      throw Exception('Analysis record not found: $recordId');
    }

    final updatedRecord = record.withError(error);
    await _saveRecord(updatedRecord);
    return updatedRecord;
  }

  /// Načte analysis record podle ID
  Future<EnhancedAnalysisRecord?> getRecord(String recordId) async {
    final db = await _getDatabase();
    final maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [recordId],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return _recordFromMap(maps.first);
  }

  /// Načte všechny records pro uživatele
  Future<List<EnhancedAnalysisRecord>> getRecordsForUser({
    required String userId,
    int? limit,
    int? offset,
    AnalysisStatus? statusFilter,
  }) async {
    final db = await _getDatabase();
    
    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];
    
    if (statusFilter != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(statusFilter.name);
    }

    final maps = await db.query(
      _tableName,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => _recordFromMap(map)).toList();
  }

  /// Vyhledá records podle různých kritérií
  Future<List<EnhancedAnalysisRecord>> searchRecords({
    String? userId,
    AnalysisStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    double? minConfidenceScore,
    double? maxConfidenceScore,
    bool? wasSuccessful,
    bool? hasFeedback,
    int? limit,
    int? offset,
  }) async {
    final db = await _getDatabase();
    
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (userId != null) {
      whereClauses.add('user_id = ?');
      whereArgs.add(userId);
    }

    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status.name);
    }

    if (fromDate != null) {
      whereClauses.add('created_at >= ?');
      whereArgs.add(fromDate.millisecondsSinceEpoch);
    }

    if (toDate != null) {
      whereClauses.add('created_at <= ?');
      whereArgs.add(toDate.millisecondsSinceEpoch);
    }

    if (minConfidenceScore != null) {
      whereClauses.add('overall_confidence >= ?');
      whereArgs.add(minConfidenceScore);
    }

    if (maxConfidenceScore != null) {
      whereClauses.add('overall_confidence <= ?');
      whereArgs.add(maxConfidenceScore);
    }

    if (hasFeedback != null) {
      if (hasFeedback) {
        whereClauses.add('user_feedback IS NOT NULL');
      } else {
        whereClauses.add('user_feedback IS NULL');
      }
    }

    final whereClause = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final maps = await db.query(
      _tableName,
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => _recordFromMap(map)).toList();
  }

  /// Získá statistiky análýz
  Future<AnalysisStatistics> getAnalysisStatistics({
    String? userId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final records = await searchRecords(
      userId: userId,
      fromDate: fromDate,
      toDate: toDate,
    );

    final totalAnalyses = records.length;
    final completedAnalyses = records.where((r) => r.isCompleted).length;
    final successfulAnalyses = records.where((r) => r.wasSuccessful).length;
    final withFeedback = records.where((r) => r.hasFeedback).length;

    final confidenceScores = records
        .where((r) => r.confidenceScore != null)
        .map((r) => r.confidenceScore!.overallConfidence)
        .toList();

    final averageConfidence = confidenceScores.isNotEmpty
        ? confidenceScores.reduce((a, b) => a + b) / confidenceScores.length
        : 0.0;

    final processingTimes = records
        .where((r) => r.processingTime != null)
        .map((r) => r.processingTime!.inMilliseconds)
        .toList();

    final averageProcessingTime = processingTimes.isNotEmpty
        ? Duration(milliseconds: 
            (processingTimes.reduce((a, b) => a + b) / processingTimes.length).round())
        : Duration.zero;

    return AnalysisStatistics(
      totalAnalyses: totalAnalyses,
      completedAnalyses: completedAnalyses,
      successfulAnalyses: successfulAnalyses,
      withFeedback: withFeedback,
      averageConfidence: averageConfidence,
      averageProcessingTime: averageProcessingTime,
      successRate: totalAnalyses > 0 ? successfulAnalyses / totalAnalyses : 0.0,
      completionRate: totalAnalyses > 0 ? completedAnalyses / totalAnalyses : 0.0,
      feedbackRate: totalAnalyses > 0 ? withFeedback / totalAnalyses : 0.0,
    );
  }

  /// Generuje improvement suggestions na základě historie
  Future<List<ImprovementSuggestion>> getHistoricalImprovementSuggestions({
    String? userId,
    int? lookbackDays,
  }) async {
    final fromDate = lookbackDays != null 
        ? DateTime.now().subtract(Duration(days: lookbackDays))
        : null;

    final records = await searchRecords(
      userId: userId,
      fromDate: fromDate,
    );

    final suggestions = <ImprovementSuggestion>[];

    // Analyzuje patterns v datech
    for (final record in records) {
      final recordSuggestions = record.getImprovementSuggestions();
      suggestions.addAll(recordSuggestions);
    }

    // Seskupí a prioritizuje suggestions
    return _consolidateImprovementSuggestions(suggestions);
  }

  /// Exportuje analysis records do JSON formátu
  Future<String> exportRecordsToJson({
    String? userId,
    DateTime? fromDate,
    DateTime? toDate,
    bool includeImages = false,
  }) async {
    final records = await searchRecords(
      userId: userId,
      fromDate: fromDate,
      toDate: toDate,
    );

    final exportData = {
      'export_date': DateTime.now().toIso8601String(),
      'total_records': records.length,
      'records': records.map((record) {
        final recordMap = record.toJson();
        
        // Optionally exclude image data to reduce size
        if (!includeImages && recordMap.containsKey('storedImages')) {
          recordMap.remove('storedImages');
        }
        
        return recordMap;
      }).toList(),
    };

    return jsonEncode(exportData);
  }

  /// Smaže staré records (data retention)
  Future<int> cleanupOldRecords({
    int? retentionDays = 365,
  }) async {
    if (retentionDays == null) return 0;

    final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
    final db = await _getDatabase();

    return await db.delete(
      _tableName,
      where: 'created_at < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );
  }

  /// Private helper methods
  Future<Database> _getDatabase() async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    _database = await DatabaseHelper.database;
    return _database!;
  }

  Future<void> _saveRecord(EnhancedAnalysisRecord record) async {
    final db = await _getDatabase();
    await db.insert(
      _tableName,
      _recordToMap(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, dynamic> _recordToMap(EnhancedAnalysisRecord record) {
    return {
      'id': record.id,
      'created_at': record.createdAt.millisecondsSinceEpoch,
      'completed_at': record.completedAt?.millisecondsSinceEpoch,
      'status': record.status.name,
      'user_id': record.inputData.userId,
      'session_id': record.inputData.sessionId,
      'reference_image_path': record.inputData.referenceImagePath,
      'part_image_path': record.inputData.partImagePath,
      'overall_confidence': record.confidenceScore?.overallConfidence,
      'processing_time_ms': record.processingTime?.inMilliseconds,
      'tokens_used': record.tokensUsed,
      'estimated_cost': record.estimatedCost,
      'was_recommendation_followed': record.wasRecommendationFollowed ? 1 : 0,
      'record_data': jsonEncode(record.toJson()), // Full record as JSON blob
    };
  }

  EnhancedAnalysisRecord _recordFromMap(Map<String, dynamic> map) {
    final recordData = jsonDecode(map['record_data'] as String) as Map<String, dynamic>;
    return EnhancedAnalysisRecord.fromJson(recordData);
  }

  Future<Uint8List> _compressImage(Uint8List imageData, String compressionLevel) async {
    // Placeholder for image compression logic
    // In real implementation, would use image compression library
    switch (compressionLevel) {
      case 'low':
        return imageData; // No compression
      case 'medium':
        return imageData; // 50% quality compression
      case 'high':
        return imageData; // 25% quality compression
      default:
        return imageData;
    }
  }

  List<ImprovementSuggestion> _consolidateImprovementSuggestions(
    List<ImprovementSuggestion> suggestions,
  ) {
    // Group suggestions by category
    final categoryGroups = <ImprovementCategory, List<ImprovementSuggestion>>{};
    
    for (final suggestion in suggestions) {
      categoryGroups.putIfAbsent(suggestion.category, () => []).add(suggestion);
    }

    // Create consolidated suggestions for each category
    final consolidated = <ImprovementSuggestion>[];
    
    for (final entry in categoryGroups.entries) {
      final category = entry.key;
      final categorySuggestions = entry.value;
      
      // Calculate average expected impact
      final avgImpact = categorySuggestions
          .map((s) => s.expectedImpact)
          .reduce((a, b) => a + b) / categorySuggestions.length;
      
      // Determine priority based on frequency and impact
      final priority = _determinePriorityFromFrequencyAndImpact(
        categorySuggestions.length,
        avgImpact,
      );

      consolidated.add(ImprovementSuggestion(
        category: category,
        priority: priority,
        description: _getCategoryDescription(category, categorySuggestions.length),
        expectedImpact: avgImpact,
      ));
    }

    // Sort by priority and expected impact
    consolidated.sort((a, b) {
      final priorityComparison = b.priority.index.compareTo(a.priority.index);
      if (priorityComparison != 0) return priorityComparison;
      return b.expectedImpact.compareTo(a.expectedImpact);
    });

    return consolidated;
  }

  SuggestionPriority _determinePriorityFromFrequencyAndImpact(
    int frequency,
    double avgImpact,
  ) {
    final score = frequency * avgImpact;
    
    if (score >= 5.0) return SuggestionPriority.critical;
    if (score >= 3.0) return SuggestionPriority.high;
    if (score >= 1.5) return SuggestionPriority.medium;
    return SuggestionPriority.low;
  }

  String _getCategoryDescription(ImprovementCategory category, int frequency) {
    final baseDescription = _getCategoryBaseDescription(category);
    return '$baseDescription (${frequency}x zaznamenaných případů)';
  }

  String _getCategoryBaseDescription(ImprovementCategory category) {
    switch (category) {
      case ImprovementCategory.imageQuality:
        return 'Zlepšit kvalitu vstupních snímků';
      case ImprovementCategory.analysisConfidence:
        return 'Zvýšit jistotu analýzy';
      case ImprovementCategory.modelPerformance:
        return 'Zlepšit výkonnost AI modelu';
      case ImprovementCategory.userExperience:
        return 'Vylepšit uživatelský zážitek';
      case ImprovementCategory.performance:
        return 'Optimalizovat rychlost systému';
    }
  }
}

/// Statistiky análýz
class AnalysisStatistics {
  final int totalAnalyses;
  final int completedAnalyses;
  final int successfulAnalyses;
  final int withFeedback;
  final double averageConfidence;
  final Duration averageProcessingTime;
  final double successRate;
  final double completionRate;
  final double feedbackRate;

  const AnalysisStatistics({
    required this.totalAnalyses,
    required this.completedAnalyses,
    required this.successfulAnalyses,
    required this.withFeedback,
    required this.averageConfidence,
    required this.averageProcessingTime,
    required this.successRate,
    required this.completionRate,
    required this.feedbackRate,
  });
}