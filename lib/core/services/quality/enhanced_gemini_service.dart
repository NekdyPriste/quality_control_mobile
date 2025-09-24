import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/comparison_result.dart';
import '../../models/quality_report.dart';
import '../../models/quality/enhanced_analysis_record.dart';
import '../../models/quality/pre_analysis_result.dart';
import '../../models/quality/enhanced_confidence_score.dart';
import '../../models/quality/action_recommendation.dart';
import '../../models/quality/analysis_feedback.dart';

import '../gemini_service.dart';
import 'enhanced_confidence_service.dart';
import 'recommendation_engine_service.dart';
import 'feedback_collection_service.dart';
import 'enhanced_analysis_record_service.dart';

final enhancedGeminiServiceProvider = Provider<EnhancedGeminiService>((ref) {
  return EnhancedGeminiService(
    geminiService: ref.read(geminiServiceProvider),
    confidenceService: ref.read(enhancedConfidenceServiceProvider),
    recommendationService: ref.read(recommendationEngineServiceProvider),
    feedbackService: ref.read(feedbackCollectionServiceProvider),
    recordService: ref.read(enhancedAnalysisRecordServiceProvider),
  );
});

class EnhancedGeminiService {
  final GeminiService _geminiService;
  final EnhancedConfidenceService _confidenceService;
  final RecommendationEngineService _recommendationService;
  final FeedbackCollectionService _feedbackService;
  final EnhancedAnalysisRecordService _recordService;

  EnhancedGeminiService({
    required GeminiService geminiService,
    required EnhancedConfidenceService confidenceService,
    required RecommendationEngineService recommendationService,
    required FeedbackCollectionService feedbackService,
    required EnhancedAnalysisRecordService recordService,
  })  : _geminiService = geminiService,
        _confidenceService = confidenceService,
        _recommendationService = recommendationService,
        _feedbackService = feedbackService,
        _recordService = recordService;

  /// Hlavní metoda pro enhanced analysis s kompletním workflow
  Future<EnhancedAnalysisResult> performEnhancedAnalysis({
    required File referenceImage,
    required File partImage,
    required PartType partType,
    required String userId,
    AnalysisComplexity complexity = AnalysisComplexity.moderate,
    Map<String, dynamic>? contextualData,
  }) async {
    print('🚀 [Enhanced Analysis] START - userId: $userId, complexity: $complexity');
    print('📸 [Enhanced Analysis] Reference: ${referenceImage.path}');
    print('📸 [Enhanced Analysis] Part: ${partImage.path}');
    // 1. Vytvoří analysis record
    final record = await _recordService.createAnalysisRecord(
      referenceImagePath: referenceImage.path,
      partImagePath: partImage.path,
      userId: userId,
      additionalContext: contextualData,
    );

    try {
      // 2. Pre-analysis: Image Quality Evaluation
      print('🔍 [Enhanced Analysis] STEP 2: Starting image quality evaluation...');
      final preAnalysisResult = await _confidenceService.evaluateImageQuality(
        referenceImage: referenceImage,
        partImage: partImage,
        contextualData: contextualData,
      );
      print('✅ [Enhanced Analysis] STEP 2: Quality evaluation completed - Decision: ${preAnalysisResult.decision}');

      // Update record s quality analysis
      await _recordService.updateWithQualityAnalysis(
        recordId: record.id,
        referenceQuality: preAnalysisResult.referenceQuality!,
        partQuality: preAnalysisResult.partQuality!,
      );

      // 3. Rozhodnutí na základě pre-analysis
      print('🔀 [Enhanced Analysis] STEP 3: Processing decision - ${preAnalysisResult.decision}');
      switch (preAnalysisResult.decision) {
        case PreAnalysisDecision.rejectAndRetake:
          print('❌ [Enhanced Analysis] REJECT_AND_RETAKE path');
          return await _handleRejectAndRetake(record.id, preAnalysisResult);

        case PreAnalysisDecision.optimizeFirst:
          print('⚙️ [Enhanced Analysis] OPTIMIZE_FIRST path');
          return await _handleOptimizeFirst(record.id, preAnalysisResult);

        case PreAnalysisDecision.proceedWithWarning:
        case PreAnalysisDecision.proceed:
          print('🚀 [Enhanced Analysis] PROCEED_WITH_AI path');
          return await _proceedWithAIAnalysis(
            recordId: record.id,
            referenceImage: referenceImage,
            partImage: partImage,
            partType: partType,
            complexity: complexity,
            preAnalysisResult: preAnalysisResult,
          );
      }
    } catch (error) {
      // Mark record as failed
      await _recordService.markRecordAsFailed(
        recordId: record.id,
        error: error.toString(),
      );
      
      rethrow;
    }
  }

  /// Zpracuje reject and retake scenario
  Future<EnhancedAnalysisResult> _handleRejectAndRetake(
    String recordId,
    PreAnalysisResult preAnalysisResult,
  ) async {
    // Generuje recommendation pro retake
    final recommendation = ActionRecommendation.generateRecommendations(
      referenceQuality: preAnalysisResult.referenceQuality!,
      partQuality: preAnalysisResult.partQuality!,
      confidenceScore: EnhancedConfidenceScore.calculate(
        referenceQuality: preAnalysisResult.referenceQuality!,
        partQuality: preAnalysisResult.partQuality!,
        complexity: AnalysisComplexity.simple,
        history: await _confidenceService.getModelPerformanceHistory(),
        contextualData: {'decision': 'reject'},
      ),
      issues: preAnalysisResult.issues,
    );

    // Update record s recommendation
    await _recordService.updateWithConfidenceScore(
      recordId: recordId,
      confidenceScore: EnhancedConfidenceScore.calculate(
        referenceQuality: preAnalysisResult.referenceQuality!,
        partQuality: preAnalysisResult.partQuality!,
        complexity: AnalysisComplexity.simple,
        history: await _confidenceService.getModelPerformanceHistory(),
        contextualData: {'decision': 'reject'},
      ),
      recommendation: recommendation,
    );

    return EnhancedAnalysisResult(
      recordId: recordId,
      decision: AnalysisDecision.retakeRequired,
      preAnalysisResult: preAnalysisResult,
      recommendation: recommendation,
      tokensSaved: preAnalysisResult.tokenSaving.savedTokens,
      costSaved: preAnalysisResult.tokenSaving.savedCostUSD,
    );
  }

  /// Zpracuje optimize first scenario
  Future<EnhancedAnalysisResult> _handleOptimizeFirst(
    String recordId,
    PreAnalysisResult preAnalysisResult,
  ) async {
    // Generuje optimization recommendations
    final recommendations = await _recommendationService.generateRecommendations(
      referenceQuality: preAnalysisResult.referenceQuality!,
      partQuality: preAnalysisResult.partQuality!,
      confidenceScore: EnhancedConfidenceScore.calculate(
        referenceQuality: preAnalysisResult.referenceQuality!,
        partQuality: preAnalysisResult.partQuality!,
        complexity: AnalysisComplexity.moderate,
        history: await _confidenceService.getModelPerformanceHistory(),
        contextualData: {'decision': 'optimize'},
      ),
      preAnalysisResult: preAnalysisResult,
    );

    final primaryRecommendation = recommendations.isNotEmpty ? recommendations.first : null;

    // Update record
    await _recordService.updateWithConfidenceScore(
      recordId: recordId,
      confidenceScore: EnhancedConfidenceScore.calculate(
        referenceQuality: preAnalysisResult.referenceQuality!,
        partQuality: preAnalysisResult.partQuality!,
        complexity: AnalysisComplexity.moderate,
        history: await _confidenceService.getModelPerformanceHistory(),
        contextualData: {'decision': 'optimize'},
      ),
      recommendation: primaryRecommendation,
    );

    return EnhancedAnalysisResult(
      recordId: recordId,
      decision: AnalysisDecision.optimizeFirst,
      preAnalysisResult: preAnalysisResult,
      recommendation: primaryRecommendation,
      allRecommendations: recommendations,
      tokensSaved: preAnalysisResult.tokenSaving.savedTokens,
      costSaved: preAnalysisResult.tokenSaving.savedCostUSD,
    );
  }

  /// Pokračuje s AI analysis
  Future<EnhancedAnalysisResult> _proceedWithAIAnalysis({
    required String recordId,
    required File referenceImage,
    required File partImage,
    required PartType partType,
    required AnalysisComplexity complexity,
    required PreAnalysisResult preAnalysisResult,
  }) async {
    print('🤖 [AI Analysis] START - recordId: $recordId');
    final startTime = DateTime.now();

    try {
      // Provede AI analýzu pomocí původního GeminiService
      print('📡 [AI Analysis] STEP 1: Calling Gemini API...');
      final aiResult = await _geminiService.analyzeImages(
        referenceImage: referenceImage,
        partImage: partImage,
        partType: partType,
      );
      print('✅ [AI Analysis] STEP 1: Gemini API completed - Result: ${aiResult.overallQuality}');

      final processingTime = DateTime.now().difference(startTime);

      // Vypočítá enhanced confidence score
      print('🧮 [AI Analysis] STEP 2: Calculating confidence score...');
      final confidenceScore = await _confidenceService.calculateFinalConfidence(
        preAnalysis: preAnalysisResult,
        aiResult: aiResult,
        complexity: complexity,
        history: await _confidenceService.getModelPerformanceHistory(),
      );
      print('✅ [AI Analysis] STEP 2: Confidence score calculated - ${confidenceScore.overallConfidence}');

      // Generuje recommendations na základě všech dostupných dat
      print('💡 [AI Analysis] STEP 3: Generating recommendations...');
      final recommendations = await _recommendationService.generateRecommendations(
        referenceQuality: preAnalysisResult.referenceQuality!,
        partQuality: preAnalysisResult.partQuality!,
        confidenceScore: confidenceScore,
        preAnalysisResult: preAnalysisResult,
        aiResult: aiResult,
      );

      // Update record s AI results
      final qualityReport = QualityReport.enhanced(
        overallScore: _mapQualityStatusToScore(aiResult.overallQuality),
        defectsFound: aiResult.defectsFound,
        summary: aiResult.summary,
        recommendations: recommendations.map((r) => r.description).toList(),
        confidenceLevel: confidenceScore.confidenceLevel.name,
        analysisTimestamp: DateTime.now(),
      );

      await _recordService.updateWithAIAnalysisResult(
        recordId: recordId,
        result: qualityReport,
        processingTime: processingTime,
        tokensUsed: _estimateTokensUsed(aiResult),
        estimatedCost: _estimateCost(aiResult),
      );

      // Update s confidence score
      await _recordService.updateWithConfidenceScore(
        recordId: recordId,
        confidenceScore: confidenceScore,
        recommendation: recommendations.isNotEmpty ? recommendations.first : null,
      );

      return EnhancedAnalysisResult(
        recordId: recordId,
        decision: AnalysisDecision.analysisCompleted,
        preAnalysisResult: preAnalysisResult,
        aiResult: aiResult,
        qualityReport: qualityReport,
        confidenceScore: confidenceScore,
        recommendation: recommendations.isNotEmpty ? recommendations.first : null,
        allRecommendations: recommendations,
        processingTime: processingTime,
      );
    } catch (error) {
      await _recordService.markRecordAsFailed(
        recordId: recordId,
        error: error.toString(),
      );
      rethrow;
    }
  }

  /// Označí doporučení jako následované
  Future<void> markRecommendationFollowed(String recordId) async {
    await _recordService.markRecommendationFollowed(recordId);
  }

  /// Shromáždí uživatelský feedback
  Future<AnalysisFeedback> collectUserFeedback({
    required String recordId,
    required UserSatisfaction satisfaction,
    required AccuracyRating accuracyRating,
    String? userComments,
    List<String>? reportedIssues,
    List<FeedbackSuggestion>? suggestions,
  }) async {
    final record = await _recordService.getRecord(recordId);
    if (record == null) {
      throw Exception('Analysis record not found: $recordId');
    }

    final reportedConfidence = record.confidenceScore?.overallConfidence ?? 0.5;
    final actualConfidence = _calculateActualConfidenceFromFeedback(
      accuracyRating,
      satisfaction,
    );

    // Shromáždí feedback
    final feedback = await _feedbackService.collectUserFeedback(
      analysisId: recordId,
      satisfaction: satisfaction,
      accuracyRating: accuracyRating,
      reportedConfidence: reportedConfidence,
      actualConfidence: actualConfidence,
      userComments: userComments,
      reportedIssues: reportedIssues,
      suggestions: suggestions,
    );

    // Update record s feedback
    await _recordService.updateWithUserFeedback(
      recordId: recordId,
      feedback: feedback,
    );

    return feedback;
  }

  /// Vytvoří guided feedback prompts
  Future<Map<String, dynamic>> createFeedbackPrompts(String recordId) async {
    final record = await _recordService.getRecord(recordId);
    if (record == null || record.confidenceScore == null || record.analysisResult == null) {
      throw Exception('Cannot create feedback prompts - insufficient data');
    }

    // Převede QualityReport na ComparisonResult pro compatibility
    final comparisonResult = ComparisonResult(
      overallQuality: _mapScoreToQualityStatus(record.analysisResult?.overallScore ?? 0.0),
      confidenceScore: record.confidenceScore?.overallConfidence ?? 0.0,
      defectsFound: record.analysisResult?.defectsFound ?? [],
      summary: record.analysisResult?.summary ?? '',
    );

    return await _feedbackService.createGuidedFeedbackPrompts(
      confidenceScore: record.confidenceScore!,
      analysisResult: comparisonResult,
    );
  }

  /// Získá improvement suggestions z feedback patterns
  Future<List<SystemImprovementRecommendation>> getSystemImprovementRecommendations() async {
    return await _feedbackService.getSystemImprovementRecommendations();
  }

  /// Helper methods
  double _mapQualityStatusToScore(QualityStatus status) {
    switch (status) {
      case QualityStatus.pass:
        return 0.9;
      case QualityStatus.warning:
        return 0.6;
      case QualityStatus.fail:
        return 0.3;
    }
  }

  QualityStatus _mapScoreToQualityStatus(double score) {
    if (score >= 0.8) return QualityStatus.pass;
    if (score >= 0.5) return QualityStatus.warning;
    return QualityStatus.fail;
  }

  double _calculateActualConfidenceFromFeedback(
    AccuracyRating accuracy,
    UserSatisfaction satisfaction,
  ) {
    final accuracyScore = (accuracy.index + 1) / 6.0; // 0-1 range
    final satisfactionScore = (satisfaction.index + 1) / 5.0; // 0-1 range
    
    return (accuracyScore * 0.7) + (satisfactionScore * 0.3);
  }

  int _estimateTokensUsed(ComparisonResult result) {
    // Rough estimation based on response content
    final baseTokens = 150; // Base prompt tokens
    final summaryTokens = result.summary.length ~/ 4; // ~4 chars per token
    final defectTokens = result.defectsFound.length * 20; // ~20 tokens per defect
    
    return baseTokens + summaryTokens + defectTokens;
  }

  double _estimateCost(ComparisonResult result) {
    final tokens = _estimateTokensUsed(result);
    const costPerToken = 0.00003; // Rough estimate for Gemini API
    return tokens * costPerToken;
  }
}

/// Result objekt pro enhanced analysis
class EnhancedAnalysisResult {
  final String recordId;
  final AnalysisDecision decision;
  final PreAnalysisResult preAnalysisResult;
  final ComparisonResult? aiResult;
  final QualityReport? qualityReport;
  final EnhancedConfidenceScore? confidenceScore;
  final ActionRecommendation? recommendation;
  final List<ActionRecommendation>? allRecommendations;
  final Duration? processingTime;
  final int? tokensSaved;
  final double? costSaved;

  const EnhancedAnalysisResult({
    required this.recordId,
    required this.decision,
    required this.preAnalysisResult,
    this.aiResult,
    this.qualityReport,
    this.confidenceScore,
    this.recommendation,
    this.allRecommendations,
    this.processingTime,
    this.tokensSaved,
    this.costSaved,
  });

  bool get wasSuccessful => aiResult != null && 
                           aiResult!.overallQuality != QualityStatus.fail;

  bool get hasHighConfidence => confidenceScore != null &&
                               confidenceScore!.overallConfidence >= 0.8;

  bool get requiresUserAction => decision == AnalysisDecision.retakeRequired ||
                                decision == AnalysisDecision.optimizeFirst;

  String get statusMessage {
    switch (decision) {
      case AnalysisDecision.retakeRequired:
        return 'Kvalita snímků vyžaduje přefocení';
      case AnalysisDecision.optimizeFirst:
        return 'Doporučeno optimalizovat podmínky před analýzou';
      case AnalysisDecision.analysisCompleted:
        return 'Analýza dokončena úspěšně';
    }
  }
}

enum AnalysisDecision {
  retakeRequired,      // Snímky musí být přefoceny
  optimizeFirst,       // Doporučena optimalizace před analýzou
  analysisCompleted,   // Analýza dokončena
}