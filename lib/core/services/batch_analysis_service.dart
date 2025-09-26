import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/batch_analysis.dart';
import '../models/quality_report.dart';
import '../database/database_helper.dart';
import 'gemini_service.dart';
import 'email_service.dart';
import 'batch_analysis_improved.dart';

final batchAnalysisServiceProvider = Provider<BatchAnalysisService>((ref) {
  return BatchAnalysisService(
    geminiService: ref.read(geminiServiceProvider),
    emailService: ref.read(emailServiceProvider),
    databaseHelper: DatabaseHelper(),
  );
});

class BatchAnalysisService {
  final GeminiService geminiService;
  final EmailService emailService;
  final DatabaseHelper databaseHelper;
  final _uuid = const Uuid();
  late final BatchAnalysisImproved _improvedService;
  
  final StreamController<BatchAnalysisJob> _jobUpdatesController = 
      StreamController<BatchAnalysisJob>.broadcast();
  
  Stream<BatchAnalysisJob> get jobUpdates => _jobUpdatesController.stream;
  
  final Map<String, BatchAnalysisJob> _activeJobs = {};

  BatchAnalysisService({
    required this.geminiService,
    required this.emailService,
    required this.databaseHelper,
  }) {
    _improvedService = BatchAnalysisImproved(
      geminiService: geminiService,
      databaseHelper: databaseHelper,
    );
  }

  Future<BatchAnalysisJob> createBatchJob({
    required String name,
    required List<BatchPhotoPair> photoPairs,
    String? operatorName,
    String? productionLine,
    String? batchNumber,
  }) async {
    final job = BatchAnalysisJob(
      id: _uuid.v4(),
      name: name,
      photoPairs: photoPairs,
      createdAt: DateTime.now(),
      status: BatchStatus.pending,
      totalPairs: photoPairs.length,
      operatorName: operatorName,
      productionLine: productionLine,
      batchNumber: batchNumber,
    );
    
    _activeJobs[job.id] = job;
    _jobUpdatesController.add(job);
    
    return job;
  }

  Future<void> startBatchAnalysis(String jobId) async {
    final job = _activeJobs[jobId];
    if (job == null) throw Exception('Batch job not found: $jobId');

    print('🚀 [Batch] Starting IMPROVED batch analysis for job: $jobId');

    // Použít vylepšený service s retry a timeout handling
    await _improvedService.startImprovedBatchAnalysis(
      job: job,
      controller: _jobUpdatesController,
      activeJobs: _activeJobs,
      maxRetries: 2,
      timeout: const Duration(minutes: 3),
    );

    print('✅ [Batch] Improved batch analysis completed for job: $jobId');
  }

  Future<String> generateBatchReport(String jobId) async {
    final job = _activeJobs[jobId];
    if (job == null) throw Exception('Batch job not found: $jobId');
    
    final buffer = StringBuffer();
    buffer.writeln('# Batch Analysis Report');
    buffer.writeln('**Job Name:** ${job.name}');
    buffer.writeln('**Created:** ${job.createdAt.toLocal()}');
    buffer.writeln('**Operator:** ${job.operatorName ?? 'N/A'}');
    buffer.writeln('**Production Line:** ${job.productionLine ?? 'N/A'}');
    buffer.writeln('**Batch Number:** ${job.batchNumber ?? 'N/A'}');
    buffer.writeln();
    
    // Summary statistics
    buffer.writeln('## Summary');
    buffer.writeln('- **Total Parts:** ${job.totalPairs}');
    buffer.writeln('- **Completed:** ${job.completedPairs}');
    buffer.writeln('- **Failed:** ${job.failedPairs}');
    buffer.writeln('- **Progress:** ${job.progressPercentage.toStringAsFixed(1)}%');
    buffer.writeln();
    
    // Quality results
    buffer.writeln('## Quality Results');
    buffer.writeln('- **PASS:** ${job.passCount}');
    buffer.writeln('- **FAIL:** ${job.failCount}');
    buffer.writeln('- **WARNING:** ${job.warningCount}');
    buffer.writeln();
    
    // Individual results
    buffer.writeln('## Individual Results');
    for (int i = 0; i < job.completedReports.length; i++) {
      final report = job.completedReports[i];
      buffer.writeln('### Part ${i + 1}');
      buffer.writeln('- **Result:** ${(report.comparisonResult?.overallQuality.name ?? 'UNKNOWN').toUpperCase()}');
      buffer.writeln('- **Confidence:** ${((report.comparisonResult?.confidenceScore ?? 0.0) * 100).toStringAsFixed(1)}%');
      buffer.writeln('- **Defects:** ${report.comparisonResult?.defectsFound.length ?? 0}');
      buffer.writeln('- **Summary:** ${report.comparisonResult?.summary ?? 'N/A'}');
      buffer.writeln();
    }
    
    // Errors
    if (job.errorMessages.isNotEmpty) {
      buffer.writeln('## Errors');
      for (final error in job.errorMessages) {
        buffer.writeln('- $error');
      }
    }
    
    return buffer.toString();
  }

  Future<void> sendBatchReport(String jobId, String recipientEmail) async {
    final reportContent = await generateBatchReport(jobId);
    final job = _activeJobs[jobId];
    
    if (job != null && job.completedReports.isNotEmpty) {
      // Use the first completed report for the email format
      final firstReport = job.completedReports.first;
      await emailService.sendQualityReport(
        inspectionId: 0, // Batch job doesn't have single inspection ID
        recipientEmail: recipientEmail,
        partType: PartType.vylisky, // Default, could be mixed in batch
        comparisonResult: firstReport.comparisonResult!,
        operatorName: job.operatorName,
      );
    }
  }

  BatchAnalysisJob? getJob(String jobId) => _activeJobs[jobId];
  
  List<BatchAnalysisJob> get activeJobs => _activeJobs.values.toList();

  void dispose() {
    _jobUpdatesController.close();
  }
}