import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/quality/analysis_feedback.dart';
import '../../models/quality/enhanced_confidence_score.dart';
import '../../models/comparison_result.dart';
import '../../models/quality_report.dart';

final feedbackCollectionServiceProvider = Provider<FeedbackCollectionService>((ref) {
  return FeedbackCollectionService();
});

class FeedbackCollectionService {
  static const String _feedbackStorageKey = 'analysis_feedback_history';
  static const String _modelPerformanceKey = 'model_performance_history';
  static const int _maxFeedbackHistory = 100;

  /// Shromažďuje uživatelský feedback po dokončení analýzy
  Future<AnalysisFeedback> collectUserFeedback({
    required String analysisId,
    required UserSatisfaction satisfaction,
    required AccuracyRating accuracyRating,
    required double reportedConfidence,
    required double actualConfidence,
    String? userComments,
    List<String>? reportedIssues,
    List<FeedbackSuggestion>? suggestions,
  }) async {
    // Určí typ feedbacku na základě satisfaction a accuracy
    final feedbackType = _determineFeedbackType(satisfaction, accuracyRating);
    
    AnalysisFeedback feedback;
    
    switch (feedbackType) {
      case FeedbackType.positive:
        feedback = AnalysisFeedback.createPositive(
          analysisId: analysisId,
          accuracyRating: accuracyRating,
          reportedConfidence: reportedConfidence,
          actualConfidence: actualConfidence,
          comments: userComments,
        );
        break;
        
      case FeedbackType.negative:
        feedback = AnalysisFeedback.createNegative(
          analysisId: analysisId,
          accuracyRating: accuracyRating,
          reportedIssues: reportedIssues ?? [],
          reportedConfidence: reportedConfidence,
          actualConfidence: actualConfidence,
          comments: userComments,
          suggestions: suggestions,
        );
        break;
        
      case FeedbackType.mixed:
        feedback = AnalysisFeedback.createMixed(
          analysisId: analysisId,
          accuracyRating: accuracyRating,
          partialIssues: reportedIssues ?? [],
          suggestions: suggestions ?? [],
          reportedConfidence: reportedConfidence,
          actualConfidence: actualConfidence,
          comments: userComments,
        );
        break;
    }

    // Uloží feedback do lokálního úložiště
    await _storeFeedback(feedback);
    
    // Aktualizuje model performance history
    await _updateModelPerformanceHistory(feedback);

    return feedback;
  }

  /// Vytvoří guided feedback collection pro uživatele
  Future<Map<String, dynamic>> createGuidedFeedbackPrompts({
    required EnhancedConfidenceScore confidenceScore,
    required ComparisonResult analysisResult,
  }) async {
    final prompts = <String, dynamic>{};

    // 1. Základní satisfaction rating
    prompts['satisfaction'] = {
      'question': 'Jak jste spokojeni s výsledky analýzy?',
      'type': 'rating',
      'scale': 5,
      'labels': ['Velmi nespokojen', 'Nespokojen', 'Neutrální', 'Spokojen', 'Velmi spokojen'],
    };

    // 2. Accuracy rating
    prompts['accuracy'] = {
      'question': 'Jak přesné jsou nalezené defekty?',
      'type': 'rating',
      'scale': 6,
      'labels': ['Velmi špatné (0-20%)', 'Špatné (21-40%)', 'Přijatelné (41-60%)', 
                 'Dobré (61-80%)', 'Velmi dobré (81-95%)', 'Vynikající (96-100%)'],
    };

    // 3. Confidence validation
    prompts['confidence_validation'] = {
      'question': 'Jak jistí jste si svým hodnocením přesnosti?',
      'type': 'slider',
      'min': 0.0,
      'max': 1.0,
      'current': confidenceScore.overallConfidence,
      'description': 'Původní jistota systému: ${(confidenceScore.overallConfidence * 100).round()}%',
    };

    // 4. Specific issue reporting
    if (analysisResult.defectsFound.isNotEmpty) {
      prompts['defect_validation'] = {
        'question': 'Které z nalezených defektů jsou skutečně přítomny?',
        'type': 'multi_select',
        'options': analysisResult.defectsFound.asMap().entries.map((entry) {
          return {
            'id': entry.key,
            'description': entry.value.description,
            'severity': entry.value.severity.name,
          };
        }).toList(),
      };
    }

    // 5. Missed defects
    prompts['missed_defects'] = {
      'question': 'Existují defekty, které systém nezachytil?',
      'type': 'text_list',
      'placeholder': 'Popište defekty, které systém nezachytil...',
    };

    // 6. Specific suggestions based on confidence factors
    final improvementSuggestions = _generateImprovementPrompts(confidenceScore);
    if (improvementSuggestions.isNotEmpty) {
      prompts['improvements'] = {
        'question': 'Co by pomohlo zlepšit budoucí analýzy?',
        'type': 'multi_select',
        'options': improvementSuggestions,
      };
    }

    // 7. Open comments
    prompts['comments'] = {
      'question': 'Další komentáře nebo návrhy?',
      'type': 'text',
      'placeholder': 'Vaše poznámky a návrhy na zlepšení...',
      'optional': true,
    };

    return prompts;
  }

  /// Analyzuje patterns v feedbacku pro zlepšení systému
  Future<FeedbackAnalysisReport> analyzeFeedbackPatterns() async {
    final feedbackHistory = await _loadFeedbackHistory();
    
    if (feedbackHistory.isEmpty) {
      return FeedbackAnalysisReport.empty();
    }

    // Analýza satisfaction trends
    final satisfactionTrend = _analyzeSatisfactionTrend(feedbackHistory);
    
    // Analýza accuracy trends
    final accuracyTrend = _analyzeAccuracyTrend(feedbackHistory);
    
    // Analýza confidence calibration
    final confidenceCalibration = _analyzeConfidenceCalibration(feedbackHistory);
    
    // Identifikace common issues
    final commonIssues = _identifyCommonIssues(feedbackHistory);
    
    // Suggestions for improvement
    final improvementAreas = _identifyImprovementAreas(feedbackHistory);

    return FeedbackAnalysisReport(
      totalFeedbackCount: feedbackHistory.length,
      satisfactionTrend: satisfactionTrend,
      accuracyTrend: accuracyTrend,
      confidenceCalibration: confidenceCalibration,
      commonIssues: commonIssues,
      improvementAreas: improvementAreas,
      analysisDate: DateTime.now(),
    );
  }

  /// Poskytuje doporučení na základě feedback patterns
  Future<List<SystemImprovementRecommendation>> getSystemImprovementRecommendations() async {
    final analysisReport = await analyzeFeedbackPatterns();
    final recommendations = <SystemImprovementRecommendation>[];

    // Doporučení na základě satisfaction trends
    if (analysisReport.satisfactionTrend.averageRating < 3.0) {
      recommendations.add(SystemImprovementRecommendation(
        category: ImprovementCategory.userExperience,
        priority: SuggestionPriority.high,
        title: 'Zlepšit uživatelskou spokojenost',
        description: 'Nízká průměrná spokojenost uživatelů vyžaduje pozornost',
        actionItems: [
          'Analyzovat nejčastější stížnosti uživatelů',
          'Zlepšit accuracy detekce defektů',
          'Optimalizovat user interface',
        ],
        expectedImpact: 0.4,
      ));
    }

    // Doporučení na základě accuracy trends
    if (analysisReport.accuracyTrend.averageAccuracy < 0.7) {
      recommendations.add(SystemImprovementRecommendation(
        category: ImprovementCategory.modelPerformance,
        priority: SuggestionPriority.critical,
        title: 'Zlepšit přesnost modelu',
        description: 'Model má nižší přesnost než požadovaných 70%',
        actionItems: [
          'Retrain model s více daty',
          'Implementovat better image preprocessing',
          'Zlepšit prompt engineering',
        ],
        expectedImpact: 0.6,
      ));
    }

    // Doporučení pro confidence calibration
    if (analysisReport.confidenceCalibration.averageDeviation > 0.2) {
      recommendations.add(SystemImprovementRecommendation(
        category: ImprovementCategory.analysisConfidence,
        priority: SuggestionPriority.medium,
        title: 'Kalibrovat confidence scoring',
        description: 'Confidence skóre není dobře kalibrováno s realitou',
        actionItems: [
          'Adjustovat váhy v confidence calculation',
          'Implementovat better contextual factors',
          'Vytvořit calibration dataset',
        ],
        expectedImpact: 0.3,
      ));
    }

    return recommendations;
  }

  /// Helpers pro feedback processing
  FeedbackType _determineFeedbackType(
    UserSatisfaction satisfaction,
    AccuracyRating accuracyRating,
  ) {
    // Kombinuje satisfaction a accuracy pro určení typu
    final satisfactionScore = satisfaction.index + 1; // 1-5
    final accuracyScore = accuracyRating.index + 1; // 1-6
    
    final combinedScore = (satisfactionScore + accuracyScore) / 2;
    
    if (combinedScore >= 4.0) {
      return FeedbackType.positive;
    } else if (combinedScore <= 2.5) {
      return FeedbackType.negative;
    } else {
      return FeedbackType.mixed;
    }
  }

  List<Map<String, dynamic>> _generateImprovementPrompts(
    EnhancedConfidenceScore confidenceScore,
  ) {
    final suggestions = <Map<String, dynamic>>[];

    for (final factor in confidenceScore.factors) {
      if (factor.score < 0.7) {
        switch (factor.type) {
          case ConfidenceFactorType.imageQuality:
            suggestions.add({
              'id': 'image_quality',
              'text': 'Lepší guidelines pro pořizování snímků',
            });
            break;
          case ConfidenceFactorType.contextual:
            suggestions.add({
              'id': 'environment_setup',
              'text': 'Zlepšení setup prostředí pro snímání',
            });
            break;
          case ConfidenceFactorType.modelReliability:
            suggestions.add({
              'id': 'model_training',
              'text': 'Více trénovacích dat pro model',
            });
            break;
          case ConfidenceFactorType.historical:
          case ConfidenceFactorType.complexity:
            // Tyto faktory se zlepšují časem
            break;
        }
      }
    }

    return suggestions;
  }

  /// Storage management methods
  Future<void> _storeFeedback(AnalysisFeedback feedback) async {
    final prefs = await SharedPreferences.getInstance();
    final feedbackHistory = await _loadFeedbackHistory();
    
    feedbackHistory.add(feedback);
    
    // Omezí historii na maximum
    if (feedbackHistory.length > _maxFeedbackHistory) {
      feedbackHistory.removeRange(0, feedbackHistory.length - _maxFeedbackHistory);
    }
    
    final jsonData = feedbackHistory.map((f) => f.toJson()).toList();
    await prefs.setString(_feedbackStorageKey, jsonEncode(jsonData));
  }

  Future<List<AnalysisFeedback>> _loadFeedbackHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_feedbackStorageKey);
    
    if (jsonString == null) return [];
    
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => AnalysisFeedback.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Pokud se nepodaří načíst historii, vrátí prázdný seznam
      return [];
    }
  }

  Future<void> _updateModelPerformanceHistory(AnalysisFeedback feedback) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load current performance
    final performanceJson = prefs.getString(_modelPerformanceKey);
    ModelPerformanceHistory? currentPerformance;
    
    if (performanceJson != null) {
      try {
        currentPerformance = ModelPerformanceHistory.fromJson(
          jsonDecode(performanceJson) as Map<String, dynamic>
        );
      } catch (e) {
        // Ignore parsing errors, create new history
      }
    }

    // Update performance metrics
    final totalAnalyses = (currentPerformance?.totalAnalyses ?? 0) + 1;
    final successfulAnalyses = (currentPerformance?.successfulAnalyses ?? 0) + 
        (feedback.isPositiveFeedback ? 1 : 0);
    
    // Calculate recent accuracy (weighted toward recent feedback)
    final currentAccuracy = _feedbackToAccuracyScore(feedback);
    final previousRecentAccuracy = currentPerformance?.recentAccuracy ?? 0.7;
    final recentAccuracy = (previousRecentAccuracy * 0.8) + (currentAccuracy * 0.2);

    final updatedPerformance = ModelPerformanceHistory(
      totalAnalyses: totalAnalyses,
      successfulAnalyses: successfulAnalyses,
      recentAccuracy: recentAccuracy,
      lastUpdated: DateTime.now(),
    );

    // Save updated performance
    await prefs.setString(
      _modelPerformanceKey,
      jsonEncode(updatedPerformance.toJson())
    );
  }

  double _feedbackToAccuracyScore(AnalysisFeedback feedback) {
    switch (feedback.accuracyRating) {
      case AccuracyRating.excellent:
        return 1.0;
      case AccuracyRating.veryGood:
        return 0.9;
      case AccuracyRating.good:
        return 0.75;
      case AccuracyRating.acceptable:
        return 0.6;
      case AccuracyRating.poor:
        return 0.3;
      case AccuracyRating.veryPoor:
        return 0.1;
    }
  }

  /// Analysis helper methods
  SatisfactionTrend _analyzeSatisfactionTrend(List<AnalysisFeedback> feedback) {
    final satisfactionScores = feedback
        .map((f) => (f.satisfaction.index + 1).toDouble())
        .toList();
    
    final average = satisfactionScores.reduce((a, b) => a + b) / satisfactionScores.length;
    
    // Simple trend calculation (last 10 vs first 10)
    final recent = satisfactionScores.length > 10 
        ? satisfactionScores.skip(satisfactionScores.length - 10).toList()
        : satisfactionScores;
    final early = satisfactionScores.take(10).toList();
    
    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final earlyAvg = early.reduce((a, b) => a + b) / early.length;
    
    return SatisfactionTrend(
      averageRating: average,
      trendDirection: recentAvg > earlyAvg ? TrendDirection.improving : 
                     recentAvg < earlyAvg ? TrendDirection.declining : 
                     TrendDirection.stable,
      changeRate: recentAvg - earlyAvg,
    );
  }

  AccuracyTrend _analyzeAccuracyTrend(List<AnalysisFeedback> feedback) {
    final accuracyScores = feedback
        .map((f) => _feedbackToAccuracyScore(f))
        .toList();
    
    final average = accuracyScores.reduce((a, b) => a + b) / accuracyScores.length;
    
    return AccuracyTrend(
      averageAccuracy: average,
      trendDirection: TrendDirection.stable, // Simplified for now
      changeRate: 0.0,
    );
  }

  ConfidenceCalibrationAnalysis _analyzeConfidenceCalibration(
    List<AnalysisFeedback> feedback,
  ) {
    final deviations = feedback
        .map((f) => f.confidenceValidation.deviation)
        .toList();
    
    final averageDeviation = deviations.reduce((a, b) => a + b) / deviations.length;
    
    final wellCalibratedCount = feedback
        .where((f) => f.confidenceValidation.isAccurate)
        .length;
    
    return ConfidenceCalibrationAnalysis(
      averageDeviation: averageDeviation,
      calibrationAccuracy: wellCalibratedCount / feedback.length,
      overconfidenceRate: feedback
          .where((f) => f.confidenceValidation.calibrationCategory == 
                       ConfidenceCalibration.overconfident)
          .length / feedback.length,
      underconfidenceRate: feedback
          .where((f) => f.confidenceValidation.calibrationCategory == 
                       ConfidenceCalibration.underconfident)
          .length / feedback.length,
    );
  }

  List<String> _identifyCommonIssues(List<AnalysisFeedback> feedback) {
    final issueFrequency = <String, int>{};
    
    for (final fb in feedback) {
      for (final issue in fb.reportedIssues) {
        issueFrequency[issue] = (issueFrequency[issue] ?? 0) + 1;
      }
    }
    
    // Vrátí top 5 nejčastějších issues
    final sortedIssues = issueFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedIssues.take(5).map((e) => e.key).toList();
  }

  List<ImprovementArea> _identifyImprovementAreas(
    List<AnalysisFeedback> feedback,
  ) {
    final areaFrequency = <ImprovementArea, int>{};
    
    for (final fb in feedback) {
      for (final area in fb.getImprovementAreas()) {
        areaFrequency[area] = (areaFrequency[area] ?? 0) + 1;
      }
    }
    
    // Vrátí areas s frequency > 10% of feedback
    final threshold = (feedback.length * 0.1).round();
    return areaFrequency.entries
        .where((e) => e.value >= threshold)
        .map((e) => e.key)
        .toList();
  }
}

/// Pomocné třídy pro feedback analysis
class FeedbackAnalysisReport {
  final int totalFeedbackCount;
  final SatisfactionTrend satisfactionTrend;
  final AccuracyTrend accuracyTrend;
  final ConfidenceCalibrationAnalysis confidenceCalibration;
  final List<String> commonIssues;
  final List<ImprovementArea> improvementAreas;
  final DateTime analysisDate;

  const FeedbackAnalysisReport({
    required this.totalFeedbackCount,
    required this.satisfactionTrend,
    required this.accuracyTrend,
    required this.confidenceCalibration,
    required this.commonIssues,
    required this.improvementAreas,
    required this.analysisDate,
  });

  factory FeedbackAnalysisReport.empty() => FeedbackAnalysisReport(
    totalFeedbackCount: 0,
    satisfactionTrend: SatisfactionTrend(
      averageRating: 3.0,
      trendDirection: TrendDirection.stable,
      changeRate: 0.0,
    ),
    accuracyTrend: AccuracyTrend(
      averageAccuracy: 0.7,
      trendDirection: TrendDirection.stable,
      changeRate: 0.0,
    ),
    confidenceCalibration: ConfidenceCalibrationAnalysis(
      averageDeviation: 0.2,
      calibrationAccuracy: 0.7,
      overconfidenceRate: 0.2,
      underconfidenceRate: 0.1,
    ),
    commonIssues: [],
    improvementAreas: [],
    analysisDate: DateTime.now(),
  );
}

class SatisfactionTrend {
  final double averageRating;
  final TrendDirection trendDirection;
  final double changeRate;

  const SatisfactionTrend({
    required this.averageRating,
    required this.trendDirection,
    required this.changeRate,
  });
}

class AccuracyTrend {
  final double averageAccuracy;
  final TrendDirection trendDirection;
  final double changeRate;

  const AccuracyTrend({
    required this.averageAccuracy,
    required this.trendDirection,
    required this.changeRate,
  });
}

class ConfidenceCalibrationAnalysis {
  final double averageDeviation;
  final double calibrationAccuracy;
  final double overconfidenceRate;
  final double underconfidenceRate;

  const ConfidenceCalibrationAnalysis({
    required this.averageDeviation,
    required this.calibrationAccuracy,
    required this.overconfidenceRate,
    required this.underconfidenceRate,
  });
}

class SystemImprovementRecommendation {
  final ImprovementCategory category;
  final SuggestionPriority priority;
  final String title;
  final String description;
  final List<String> actionItems;
  final double expectedImpact;

  const SystemImprovementRecommendation({
    required this.category,
    required this.priority,
    required this.title,
    required this.description,
    required this.actionItems,
    required this.expectedImpact,
  });
}

enum TrendDirection { improving, declining, stable }