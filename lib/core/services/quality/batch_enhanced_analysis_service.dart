import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/batch_analysis.dart';
import '../../models/batch_enhanced_result.dart';
import '../../models/batch_overall_analysis.dart';
import '../../models/quality/enhanced_confidence_score.dart';
import '../../models/quality_report.dart';
import 'enhanced_gemini_service.dart';
import 'enhanced_analysis_record_service.dart';
import '../../database/database_helper.dart';

final batchEnhancedAnalysisServiceProvider = Provider<BatchEnhancedAnalysisService>((ref) {
  return BatchEnhancedAnalysisService(
    enhancedGeminiService: ref.read(enhancedGeminiServiceProvider),
    recordService: ref.read(enhancedAnalysisRecordServiceProvider),
    databaseHelper: DatabaseHelper(),
  );
});

/// Service pro Enhanced Analysis v batch operacích
class BatchEnhancedAnalysisService {
  final EnhancedGeminiService _enhancedGeminiService;
  final EnhancedAnalysisRecordService _recordService;
  final DatabaseHelper _databaseHelper;

  final StreamController<BatchAnalysisJob> _jobUpdatesController =
      StreamController<BatchAnalysisJob>.broadcast();

  Stream<BatchAnalysisJob> get jobUpdates => _jobUpdatesController.stream;

  BatchEnhancedAnalysisService({
    required EnhancedGeminiService enhancedGeminiService,
    required EnhancedAnalysisRecordService recordService,
    required DatabaseHelper databaseHelper,
  })  : _enhancedGeminiService = enhancedGeminiService,
        _recordService = recordService,
        _databaseHelper = databaseHelper;

  /// Analyzuje jednotlivý photo pair pomocí Enhanced Analysis
  Future<BatchEnhancedResult> analyzePhotoPairEnhanced({
    required String pairId,
    required String referenceImagePath,
    required String partImagePath,
    required PartType partType,
    required String userId,
    required AnalysisComplexity complexity,
    String? partSerial,
  }) async {
    print('🚀 [Batch Enhanced] START - pairId: $pairId, complexity: ${complexity.name}');
    final startTime = DateTime.now();

    try {
      // Create pending result
      var result = BatchEnhancedResult.pending(
        pairId: pairId,
        referenceImagePath: referenceImagePath,
        partImagePath: partImagePath,
        partType: partType,
        partSerial: partSerial,
      );

      // Update to processing
      result = result.copyWith(status: BatchEnhancedStatus.processing);

      // Run Enhanced Analysis
      final enhancedAnalysisResult = await _enhancedGeminiService.performEnhancedAnalysis(
        referenceImage: File(referenceImagePath),
        partImage: File(partImagePath),
        partType: partType,
        userId: userId,
        complexity: complexity,
      );

      final processingTime = DateTime.now().difference(startTime);

      // Create basic ComparisonResult from Enhanced Analysis
      final basicResult = enhancedAnalysisResult.aiResult;

      print('✅ [Batch Enhanced] COMPLETED - pairId: $pairId, status: ${basicResult?.overallQuality.name}, time: ${processingTime.inMilliseconds}ms');

      // Return completed result (without EnhancedAnalysisRecord for now)
      // TODO: Create proper EnhancedAnalysisRecord when all required data structures are available
      return BatchEnhancedResult.completed(
        pairId: pairId,
        referenceImagePath: referenceImagePath,
        partImagePath: partImagePath,
        partType: partType,
        partSerial: partSerial,
        enhancedRecord: null, // Will be populated later when we have full record service integration
        basicResult: basicResult!,
        processingTime: processingTime,
        tokensUsed: enhancedAnalysisResult.tokensSaved,
        estimatedCost: 0.0, // Calculate actual cost if needed
      );

    } catch (e) {
      final processingTime = DateTime.now().difference(startTime);
      print('❌ [Batch Enhanced] FAILED - pairId: $pairId, error: $e');

      return BatchEnhancedResult.failed(
        pairId: pairId,
        referenceImagePath: referenceImagePath,
        partImagePath: partImagePath,
        partType: partType,
        partSerial: partSerial,
        errorMessage: e.toString(),
        processingTime: processingTime,
      );
    }
  }

  /// Zpracuje celý batch s Enhanced Analysis
  Future<BatchAnalysisJob> processEnhancedBatch({
    required BatchAnalysisJob job,
    required String userId,
    bool saveToDatabase = true,
  }) async {
    print('🎯 [Batch Enhanced] BATCH START - ${job.name}, pairs: ${job.photoPairs.length}');

    if (!job.useEnhancedAnalysis) {
      throw ArgumentError('Job must be configured for Enhanced Analysis');
    }

    final startTime = DateTime.now();
    final enhancedResults = <BatchEnhancedResult>[];
    var updatedJob = job.copyWith(status: BatchStatus.processing);

    try {
      // Process each photo pair with Enhanced Analysis
      for (int i = 0; i < job.photoPairs.length; i++) {
        final pair = job.photoPairs[i];

        // Analyze with Enhanced Analysis
        final result = await analyzePhotoPairEnhanced(
          pairId: pair.id,
          referenceImagePath: pair.referenceImagePath,
          partImagePath: pair.partImagePath,
          partType: pair.partType,
          userId: userId,
          complexity: job.enhancedComplexity,
          partSerial: pair.partSerial,
        );

        enhancedResults.add(result);

        // Update progress
        final completedCount = enhancedResults.where((r) => r.isCompleted).length;
        final failedCount = enhancedResults.where((r) => r.isFailed).length;

        updatedJob = updatedJob.copyWith(
          completedPairs: completedCount,
          failedPairs: failedCount,
          enhancedResults: List.from(enhancedResults),
        );

        // Emit progress update
        _jobUpdatesController.add(updatedJob);

        // Small delay to prevent overwhelming the system
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final totalProcessingTime = DateTime.now().difference(startTime);

      // Generate overall analysis
      final overallAnalysis = BatchOverallAnalysis.fromBatchResults(
        batchId: job.id,
        results: enhancedResults,
        totalProcessingTime: totalProcessingTime,
      );

      // Create final job
      final completedJob = updatedJob.copyWith(
        status: BatchStatus.completed,
        enhancedResults: enhancedResults,
        overallAnalysis: overallAnalysis,
      );

      // Save to database if requested
      if (saveToDatabase) {
        await _saveBatchResultsToDatabase(completedJob);
      }

      print('🎉 [Batch Enhanced] BATCH COMPLETED - ${job.name}');
      print('📊 Stats: ${overallAnalysis.statistics.successfulCount}/${overallAnalysis.statistics.totalProcessed} passed');
      print('⏱️ Total time: ${totalProcessingTime.inMinutes} minutes');

      _jobUpdatesController.add(completedJob);
      return completedJob;

    } catch (e) {
      print('❌ [Batch Enhanced] BATCH FAILED - ${job.name}, error: $e');

      final failedJob = updatedJob.copyWith(
        status: BatchStatus.failed,
        errorMessages: [...job.errorMessages, e.toString()],
        enhancedResults: enhancedResults,
      );

      _jobUpdatesController.add(failedJob);
      return failedJob;
    }
  }

  /// Generuje overall analýzu z batch results
  Future<BatchOverallAnalysis> generateOverallAnalysis({
    required String batchId,
    required List<BatchEnhancedResult> results,
    required Duration totalProcessingTime,
  }) async {
    return BatchOverallAnalysis.fromBatchResults(
      batchId: batchId,
      results: results,
      totalProcessingTime: totalProcessingTime,
    );
  }

  /// Uloží batch results do databáze
  Future<void> _saveBatchResultsToDatabase(BatchAnalysisJob job) async {
    try {
      // Save basic batch info
      print('💾 [Batch Enhanced] Saving to database...');

      // Save individual enhanced records
      for (final result in job.enhancedResults) {
        if (result.enhancedRecord != null && result.basicResult != null) {
          await _databaseHelper.saveInspection(
            referenceImagePath: result.referenceImagePath,
            partImagePath: result.partImagePath,
            partType: result.partType,
            comparisonResult: result.basicResult!,
            operatorName: job.operatorName,
            productionLine: job.productionLine,
            batchNumber: job.batchNumber,
            partSerial: result.partSerial,
          );
        }
      }

      print('✅ [Batch Enhanced] Database save completed');
    } catch (e) {
      print('⚠️ [Batch Enhanced] Database save failed: $e');
      // Don't throw - database save failure shouldn't fail the entire batch
    }
  }

  /// Exportuje batch results pro fine-tuning
  Future<Map<String, dynamic>> exportBatchDataForFineTuning({
    required BatchAnalysisJob job,
  }) async {
    return {
      'batchInfo': {
        'id': job.id,
        'name': job.name,
        'createdAt': job.createdAt.toIso8601String(),
        'operatorName': job.operatorName,
        'productionLine': job.productionLine,
        'batchNumber': job.batchNumber,
        'enhancedComplexity': job.enhancedComplexity.name,
      },
      'results': job.enhancedResults.map((r) => {
        'pairId': r.pairId,
        'partType': r.partType.name,
        'status': r.status.name,
        'overallQuality': r.overallQuality?.name,
        'confidenceScore': r.confidenceScore,
        'processingTime': r.processingTime.inMilliseconds,
        'tokensUsed': r.tokensUsed,
        'estimatedCost': r.estimatedCost,
        'recommendations': r.allRecommendations,
        'enhancedRecord': r.enhancedRecord?.toJson(),
      }).toList(),
      'overallAnalysis': job.overallAnalysis?.toJson(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Získá batch performance metrics
  BatchPerformanceMetrics getBatchPerformanceMetrics(BatchAnalysisJob job) {
    return BatchPerformanceMetrics.fromResults(
      job.enhancedResults,
      job.totalEnhancedProcessingTime,
    );
  }

  /// Cleanup
  void dispose() {
    _jobUpdatesController.close();
  }
}