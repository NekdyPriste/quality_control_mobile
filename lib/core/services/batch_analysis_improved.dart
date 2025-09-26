import 'dart:async';
import 'dart:io';
import '../models/batch_analysis.dart';
import '../models/quality_report.dart';
import 'gemini_service.dart';
import '../database/database_helper.dart';

/// Vylepšený batch analysis service s retry a timeout handling
class BatchAnalysisImproved {
  final GeminiService _geminiService;
  final DatabaseHelper _databaseHelper;

  BatchAnalysisImproved({
    required GeminiService geminiService,
    required DatabaseHelper databaseHelper,
  }) : _geminiService = geminiService,
       _databaseHelper = databaseHelper;

  /// Spustí batch análzu s retry mechanimem a timeouts
  Future<void> startImprovedBatchAnalysis({
    required BatchAnalysisJob job,
    required StreamController<BatchAnalysisJob> controller,
    required Map<String, BatchAnalysisJob> activeJobs,
    int maxRetries = 2,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    var currentJob = job.copyWith(status: BatchStatus.processing);
    activeJobs[job.id] = currentJob;
    controller.add(currentJob);

    final completedReports = <QualityReport>[];
    final errorMessages = <String>[];
    int completedCount = 0;
    int failedCount = 0;

    try {
      // Process pairs with concurrent processing (limited to 3 at once)
      const chunkSize = 3;
      final chunks = _chunkList(job.photoPairs, chunkSize);

      for (int chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
        final chunk = chunks[chunkIndex];

        // Process chunk concurrently with timeout
        final results = await Future.wait(
          chunk.map((pair) => _processPairWithRetry(
            pair,
            job,
            maxRetries,
            timeout,
          )),
          eagerError: false,
        );

        // Process results
        for (int i = 0; i < results.length; i++) {
          final result = results[i];
          if (result.isSuccess) {
            completedReports.add(result.report!);
            completedCount++;
          } else {
            errorMessages.add('Pair ${chunk[i].id}: ${result.error}');
            failedCount++;
          }

          // Update progress after each result
          currentJob = currentJob.copyWith(
            completedPairs: completedCount,
            failedPairs: failedCount,
            completedReports: completedReports,
            errorMessages: errorMessages,
          );
          activeJobs[job.id] = currentJob;
          controller.add(currentJob);
        }

        // Short delay between chunks
        if (chunkIndex < chunks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }

      // Mark as completed
      final finalJob = currentJob.copyWith(status: BatchStatus.completed);
      activeJobs[job.id] = finalJob;
      controller.add(finalJob);

    } catch (e) {
      // Mark as failed
      final failedJob = currentJob.copyWith(
        status: BatchStatus.failed,
        errorMessages: [...errorMessages, 'Batch failed: $e'],
      );
      activeJobs[job.id] = failedJob;
      controller.add(failedJob);
    }
  }

  /// Rozdělí list na menší chunky
  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, (i + chunkSize).clamp(0, list.length)));
    }
    return chunks;
  }

  /// Zpracuje jeden pair s retry mechanimem
  Future<_ProcessResult> _processPairWithRetry(
    BatchPhotoPair pair,
    BatchAnalysisJob job,
    int maxRetries,
    Duration timeout,
  ) async {
    Exception? lastError;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final result = await _processSinglePair(pair, job).timeout(timeout);
        return _ProcessResult.success(result);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt + 1));
        }
      }
    }

    return _ProcessResult.failure(lastError?.toString() ?? 'Unknown error');
  }

  /// Zpracuje jeden photo pair
  Future<QualityReport> _processSinglePair(BatchPhotoPair pair, BatchAnalysisJob job) async {
    final comparisonResult = await _geminiService.analyzeImages(
      referenceImage: File(pair.referenceImagePath),
      partImage: File(pair.partImagePath),
      partType: pair.partType,
    );

    final inspectionId = await _databaseHelper.saveInspection(
      referenceImagePath: pair.referenceImagePath,
      partImagePath: pair.partImagePath,
      partType: pair.partType,
      comparisonResult: comparisonResult,
      operatorName: job.operatorName,
      productionLine: job.productionLine,
      batchNumber: job.batchNumber,
      partSerial: pair.partSerial,
    );

    return QualityReport.legacy(
      id: inspectionId,
      referenceImagePath: pair.referenceImagePath,
      partImagePath: pair.partImagePath,
      partType: pair.partType,
      createdAt: DateTime.now(),
      comparisonResult: comparisonResult,
    );
  }
}

/// Helper class pro results
class _ProcessResult {
  final bool isSuccess;
  final QualityReport? report;
  final String? error;

  _ProcessResult.success(this.report) : isSuccess = true, error = null;
  _ProcessResult.failure(this.error) : isSuccess = false, report = null;
}