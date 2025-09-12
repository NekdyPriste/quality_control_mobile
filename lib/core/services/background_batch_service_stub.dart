// Stub implementation pro web platformu
// WorkManager není podporován na webu

import '../models/batch_analysis.dart';
import '../models/quality_report.dart';

class BackgroundBatchService {
  static const String batchTaskIdentifier = 'batch_analysis_task';
  
  static void initialize() {
    // Prázdná implementace pro web
    print('BackgroundBatchService: Inicializace přeskočena na web platformě');
  }
  
  static Future<void> scheduleBatchAnalysis({
    required String jobId,
    required List<BatchPhotoPair> photoPairs,
    required Map<String, String> jobData,
  }) async {
    throw UnsupportedError('Background batch analýza není podporována na web platformě');
  }
  
  static Future<void> cancelBatchAnalysis(String jobId) async {
    throw UnsupportedError('Background batch analýza není podporována na web platformě');
  }
  
  static Future<List<BatchAnalysisJob>> getBackgroundJobs() async {
    return []; // Vrací prázdný seznam pro web
  }
}