import 'package:flutter_test/flutter_test.dart';
import 'package:quality_control_mobile/core/models/quality/enhanced_confidence_score.dart';
import 'package:quality_control_mobile/core/models/quality/action_recommendation.dart';
import 'package:quality_control_mobile/core/models/quality/analysis_feedback.dart';
import 'package:quality_control_mobile/core/models/quality/enhanced_analysis_record.dart';
import 'package:quality_control_mobile/core/models/quality/image_quality_metrics.dart';
import 'dart:typed_data';

void main() {
  group('Enhanced Confidence System Tests', () {
    
    // Test data setup
    late ImageQualityMetrics highQualityMetrics;
    late ImageQualityMetrics lowQualityMetrics;
    late ImageQualityMetrics moderateQualityMetrics;

    setUp(() {
      highQualityMetrics = const ImageQualityMetrics(
        sharpness: 0.9,
        brightness: 0.6,
        contrast: 0.7,
        noiseLevel: 0.2,
        resolution: 0.9,
        compression: 0.8,
        objectCoverage: 0.7,
        edgeClarity: 0.8,
        overallScore: 0.85,
      );

      moderateQualityMetrics = const ImageQualityMetrics(
        sharpness: 0.6,
        brightness: 0.5,
        contrast: 0.5,
        noiseLevel: 0.4,
        resolution: 0.6,
        compression: 0.6,
        objectCoverage: 0.5,
        edgeClarity: 0.6,
        overallScore: 0.55,
      );

      lowQualityMetrics = const ImageQualityMetrics(
        sharpness: 0.3,
        brightness: 0.2,
        contrast: 0.3,
        noiseLevel: 0.8,
        resolution: 0.4,
        compression: 0.3,
        objectCoverage: 0.3,
        edgeClarity: 0.3,
        overallScore: 0.3,
      );
    });

    group('EnhancedConfidenceScore Tests', () {
      test('should create confidence score with factory method', () {
        final confidenceScore = EnhancedConfidenceScore.calculate(
          referenceQuality: highQualityMetrics,
          partQuality: highQualityMetrics,
          complexity: AnalysisComplexity.simple,
          history: const ModelPerformanceHistory(
            totalAnalyses: 100,
            successfulAnalyses: 85,
            recentAccuracy: 0.9,
            lastUpdated: null,
          ),
          contextualData: {
            'hasReferenceModel': true,
            'goodLightingConditions': true,
            'stableEnvironment': true,
          },
        );

        expect(confidenceScore.overallConfidence, greaterThan(0.8));
        expect(confidenceScore.factors.length, equals(5));
        expect(confidenceScore.confidenceLevel, equals(ConfidenceLevel.high));
        expect(confidenceScore.isReliableForDecisionMaking, isTrue);
      });

      test('should calculate lower confidence for poor quality inputs', () {
        final confidenceScore = EnhancedConfidenceScore.calculate(
          referenceQuality: lowQualityMetrics,
          partQuality: lowQualityMetrics,
          complexity: AnalysisComplexity.extreme,
          history: null,
          contextualData: {
            'hasReflectiveSurfaces': true,
            'poorAngle': true,
            'backgroundNoise': true,
          },
        );

        expect(confidenceScore.overallConfidence, lessThan(0.5));
        expect(confidenceScore.confidenceLevel, 
               anyOf([ConfidenceLevel.low, ConfidenceLevel.veryLow]));
        expect(confidenceScore.requiresHumanReview, isTrue);
        expect(confidenceScore.shouldShowWarnings, isTrue);
      });

      test('should handle different complexity levels correctly', () {
        final complexities = AnalysisComplexity.values;
        
        for (final complexity in complexities) {
          final confidenceScore = EnhancedConfidenceScore.calculate(
            referenceQuality: moderateQualityMetrics,
            partQuality: moderateQualityMetrics,
            complexity: complexity,
            history: null,
            contextualData: {},
          );

          // More complex analysis should have lower model reliability
          switch (complexity) {
            case AnalysisComplexity.simple:
              expect(confidenceScore.modelReliabilityScore, equals(0.95));
              break;
            case AnalysisComplexity.moderate:
              expect(confidenceScore.modelReliabilityScore, equals(0.85));
              break;
            case AnalysisComplexity.complex:
              expect(confidenceScore.modelReliabilityScore, equals(0.75));
              break;
            case AnalysisComplexity.extreme:
              expect(confidenceScore.modelReliabilityScore, equals(0.60));
              break;
          }
        }
      });

      test('should serialize to and from JSON correctly', () {
        final original = EnhancedConfidenceScore.calculate(
          referenceQuality: highQualityMetrics,
          partQuality: moderateQualityMetrics,
          complexity: AnalysisComplexity.moderate,
          history: null,
          contextualData: {'hasReferenceModel': true},
        );

        final json = original.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json.containsKey('overallConfidence'), isTrue);
        expect(json.containsKey('factors'), isTrue);

        // Note: fromJson would require generated code
        // This test verifies the toJson method works
        expect(json['overallConfidence'], isA<double>());
        expect(json['factors'], isA<List>());
      });
    });

    group('ActionRecommendation Tests', () {
      test('should generate blur recommendation for blur issues', () {
        final issues = [
          QualityIssue.blur(severity: IssueSeverity.major),
        ];

        final recommendation = ActionRecommendation.generateRecommendations(
          referenceQuality: lowQualityMetrics,
          partQuality: lowQualityMetrics,
          confidenceScore: EnhancedConfidenceScore.calculate(
            referenceQuality: lowQualityMetrics,
            partQuality: lowQualityMetrics,
            complexity: AnalysisComplexity.simple,
            history: null,
            contextualData: {},
          ),
          issues: issues,
        );

        expect(recommendation.type, equals(RecommendationType.retakePhoto));
        expect(recommendation.category, equals(RecommendationCategory.imageCapture));
        expect(recommendation.steps.length, greaterThan(0));
        expect(recommendation.isActionable, isTrue);
      });

      test('should generate lighting recommendation for lighting issues', () {
        final issues = [
          QualityIssue.lighting(severity: IssueSeverity.major),
        ];

        final recommendation = ActionRecommendation.generateRecommendations(
          referenceQuality: moderateQualityMetrics,
          partQuality: moderateQualityMetrics,
          confidenceScore: EnhancedConfidenceScore.calculate(
            referenceQuality: moderateQualityMetrics,
            partQuality: moderateQualityMetrics,
            complexity: AnalysisComplexity.simple,
            history: null,
            contextualData: {},
          ),
          issues: issues,
        );

        expect(recommendation.type, equals(RecommendationType.improveConditions));
        expect(recommendation.category, equals(RecommendationCategory.environment));
        expect(recommendation.expectedImprovement.confidenceIncrease, greaterThan(0.0));
      });

      test('should create default recommendation for high confidence', () {
        final confidenceScore = EnhancedConfidenceScore.calculate(
          referenceQuality: highQualityMetrics,
          partQuality: highQualityMetrics,
          complexity: AnalysisComplexity.simple,
          history: const ModelPerformanceHistory(
            totalAnalyses: 50,
            successfulAnalyses: 48,
            recentAccuracy: 0.95,
            lastUpdated: null,
          ),
          contextualData: {
            'hasReferenceModel': true,
            'goodLightingConditions': true,
          },
        );

        final recommendation = ActionRecommendation.defaultRecommendation(confidenceScore);

        if (confidenceScore.confidenceLevel == ConfidenceLevel.veryHigh) {
          expect(recommendation.type, equals(RecommendationType.proceed));
          expect(recommendation.priority, equals(ActionPriority.low));
        } else {
          expect(recommendation.type, equals(RecommendationType.reviewSettings));
        }
      });

      test('should handle multiple recommendation types', () {
        final recommendationTypes = RecommendationType.values;
        
        for (final type in recommendationTypes) {
          // Verify each enum value is handled
          expect(type.name, isNotEmpty);
        }
      });

      test('should calculate estimated times correctly', () {
        final recommendation = ActionRecommendation.generateRecommendations(
          referenceQuality: lowQualityMetrics,
          partQuality: lowQualityMetrics,
          confidenceScore: EnhancedConfidenceScore.calculate(
            referenceQuality: lowQualityMetrics,
            partQuality: lowQualityMetrics,
            complexity: AnalysisComplexity.simple,
            history: null,
            contextualData: {},
          ),
          issues: [QualityIssue.blur(severity: IssueSeverity.critical)],
        );

        expect(recommendation.estimatedTime.inSeconds, greaterThan(0));
        expect(recommendation.steps.every((step) => 
               step.estimatedTime.inSeconds > 0), isTrue);
      });
    });

    group('AnalysisFeedback Tests', () {
      test('should create positive feedback correctly', () {
        final feedback = AnalysisFeedback.createPositive(
          analysisId: 'test_analysis_123',
          accuracyRating: AccuracyRating.excellent,
          reportedConfidence: 0.9,
          actualConfidence: 0.85,
          comments: 'Very accurate analysis',
        );

        expect(feedback.type, equals(FeedbackType.positive));
        expect(feedback.satisfaction, equals(UserSatisfaction.verySatisfied));
        expect(feedback.isPositiveFeedback, isTrue);
        expect(feedback.isConfidenceAccurate, isTrue);
        expect(feedback.reportedIssues.isEmpty, isTrue);
      });

      test('should create negative feedback correctly', () {
        final feedback = AnalysisFeedback.createNegative(
          analysisId: 'test_analysis_456',
          accuracyRating: AccuracyRating.poor,
          reportedIssues: ['Missed defect in corner', 'False positive on surface'],
          reportedConfidence: 0.8,
          actualConfidence: 0.3,
          comments: 'Analysis was inaccurate',
        );

        expect(feedback.type, equals(FeedbackType.negative));
        expect(feedback.satisfaction, equals(UserSatisfaction.dissatisfied));
        expect(feedback.isNegativeFeedback, isTrue);
        expect(feedback.hasIssues, isTrue);
        expect(feedback.reportedIssues.length, equals(2));
        expect(feedback.confidenceValidation.isAccurate, isFalse);
      });

      test('should create mixed feedback correctly', () {
        final suggestions = [
          FeedbackSuggestion.imageQuality('Better lighting needed'),
          FeedbackSuggestion.userInterface('Add zoom feature'),
        ];

        final feedback = AnalysisFeedback.createMixed(
          analysisId: 'test_analysis_789',
          accuracyRating: AccuracyRating.acceptable,
          partialIssues: ['Partial detection issue'],
          suggestions: suggestions,
          reportedConfidence: 0.7,
          actualConfidence: 0.6,
        );

        expect(feedback.type, equals(FeedbackType.mixed));
        expect(feedback.satisfaction, equals(UserSatisfaction.neutral));
        expect(feedback.hasSuggestions, isTrue);
        expect(feedback.suggestions.length, equals(2));
      });

      test('should calculate learning weight correctly', () {
        // High weight for negative feedback with accurate confidence
        final negativeFeedback = AnalysisFeedback.createNegative(
          analysisId: 'test1',
          accuracyRating: AccuracyRating.poor,
          reportedIssues: ['Major issue'],
          reportedConfidence: 0.5,
          actualConfidence: 0.55, // Small deviation
          comments: 'This is a detailed comment explaining the issues found',
        );

        expect(negativeFeedback.learningWeight, greaterThan(1.5));

        // Lower weight for positive feedback with large confidence deviation
        final positiveFeedback = AnalysisFeedback.createPositive(
          analysisId: 'test2',
          accuracyRating: AccuracyRating.good,
          reportedConfidence: 0.9,
          actualConfidence: 0.5, // Large deviation
        );

        expect(positiveFeedback.learningWeight, lessThan(1.0));
      });

      test('should identify improvement areas correctly', () {
        final feedback = AnalysisFeedback.createNegative(
          analysisId: 'test_improvement',
          accuracyRating: AccuracyRating.poor,
          reportedIssues: [
            'Image was too blurry',
            'Poor lighting conditions',
            'Missing defect detection',
          ],
          reportedConfidence: 0.8,
          actualConfidence: 0.4,
        );

        final areas = feedback.getImprovementAreas();
        
        expect(areas, contains(ImprovementArea.modelAccuracy));
        expect(areas, contains(ImprovementArea.confidenceCalibration));
        expect(areas, contains(ImprovementArea.blurDetection));
        expect(areas, contains(ImprovementArea.lightingAssessment));
        expect(areas, contains(ImprovementArea.defectDetection));
      });

      test('should handle feedback suggestions correctly', () {
        final imageQualitySuggestion = FeedbackSuggestion.imageQuality(
          'Improve camera resolution'
        );
        final uiSuggestion = FeedbackSuggestion.userInterface(
          'Add manual focus option'
        );
        final featureSuggestion = FeedbackSuggestion.feature(
          'Auto-retry feature',
          'Automatically retry analysis with improved settings'
        );

        expect(imageQualitySuggestion.type, equals(SuggestionType.imageQuality));
        expect(imageQualitySuggestion.priority, equals(SuggestionPriority.high));

        expect(uiSuggestion.type, equals(SuggestionType.userInterface));
        expect(uiSuggestion.priority, equals(SuggestionPriority.medium));

        expect(featureSuggestion.type, equals(SuggestionType.newFeature));
        expect(featureSuggestion.priority, equals(SuggestionPriority.low));
      });
    });

    group('EnhancedAnalysisRecord Tests', () {
      test('should create new analysis record correctly', () {
        final record = EnhancedAnalysisRecord.createNew(
          referenceImagePath: '/path/to/reference.jpg',
          partImagePath: '/path/to/part.jpg',
          userId: 'user123',
          additionalContext: {'partType': 'valve', 'batch': 'B001'},
        );

        expect(record.id, isNotEmpty);
        expect(record.createdAt, isA<DateTime>());
        expect(record.status, equals(AnalysisStatus.initialized));
        expect(record.inputData.referenceImagePath, equals('/path/to/reference.jpg'));
        expect(record.inputData.partImagePath, equals('/path/to/part.jpg'));
        expect(record.inputData.userId, equals('user123'));
        expect(record.events.length, equals(1));
        expect(record.events.first.type, equals(AnalysisEventType.created));
      });

      test('should update with quality analysis correctly', () {
        final initialRecord = EnhancedAnalysisRecord.createNew(
          referenceImagePath: '/path/to/reference.jpg',
          partImagePath: '/path/to/part.jpg',
          userId: 'user123',
        );

        final updatedRecord = initialRecord.withQualityAnalysis(
          referenceQuality: highQualityMetrics,
          partQuality: moderateQualityMetrics,
        );

        expect(updatedRecord.status, equals(AnalysisStatus.qualityAnalyzed));
        expect(updatedRecord.referenceImageQuality, equals(highQualityMetrics));
        expect(updatedRecord.partImageQuality, equals(moderateQualityMetrics));
        expect(updatedRecord.events.length, equals(2));
      });

      test('should update with confidence score correctly', () {
        final record = EnhancedAnalysisRecord.createNew(
          referenceImagePath: '/path/to/reference.jpg',
          partImagePath: '/path/to/part.jpg',
          userId: 'user123',
        ).withQualityAnalysis(
          referenceQuality: highQualityMetrics,
          partQuality: moderateQualityMetrics,
        );

        final confidence = EnhancedConfidenceScore.calculate(
          referenceQuality: highQualityMetrics,
          partQuality: moderateQualityMetrics,
          complexity: AnalysisComplexity.moderate,
          history: null,
          contextualData: {},
        );

        final recommendation = ActionRecommendation.defaultRecommendation(confidence);

        final updatedRecord = record.withConfidenceScore(
          confidence: confidence,
          actionRecommendation: recommendation,
        );

        expect(updatedRecord.status, equals(AnalysisStatus.confidenceCalculated));
        expect(updatedRecord.confidenceScore, equals(confidence));
        expect(updatedRecord.recommendation, equals(recommendation));
      });

      test('should calculate overall quality score correctly', () {
        final record = EnhancedAnalysisRecord.createNew(
          referenceImagePath: '/path/to/reference.jpg',
          partImagePath: '/path/to/part.jpg',
          userId: 'user123',
        ).withQualityAnalysis(
          referenceQuality: highQualityMetrics, // 0.85
          partQuality: moderateQualityMetrics,   // 0.55
        );

        final confidence = EnhancedConfidenceScore.calculate(
          referenceQuality: highQualityMetrics,
          partQuality: moderateQualityMetrics,
          complexity: AnalysisComplexity.moderate,
          history: null,
          contextualData: {},
        );

        final recordWithConfidence = record.withConfidenceScore(confidence: confidence);

        final feedback = AnalysisFeedback.createPositive(
          analysisId: record.id,
          accuracyRating: AccuracyRating.good, // 0.75
          reportedConfidence: 0.7,
          actualConfidence: 0.7,
        );

        final finalRecord = recordWithConfidence.withUserFeedback(feedback);

        final qualityScore = finalRecord.overallQualityScore;
        
        // Should be average of: reference(0.85) + part(0.55) + confidence + feedback(0.75)
        expect(qualityScore, greaterThan(0.6));
        expect(qualityScore, lessThan(0.9));
      });

      test('should generate improvement suggestions correctly', () {
        final record = EnhancedAnalysisRecord.createNew(
          referenceImagePath: '/path/to/reference.jpg',
          partImagePath: '/path/to/part.jpg',
          userId: 'user123',
        ).withQualityAnalysis(
          referenceQuality: lowQualityMetrics, // Poor quality should generate suggestions
          partQuality: moderateQualityMetrics,
        );

        final suggestions = record.getImprovementSuggestions();
        
        expect(suggestions, isNotEmpty);
        expect(suggestions.any((s) => s.category == ImprovementCategory.imageQuality), isTrue);
      });

      test('should handle stored images correctly', () {
        final record = EnhancedAnalysisRecord.createNew(
          referenceImagePath: '/path/to/reference.jpg',
          partImagePath: '/path/to/part.jpg',
          userId: 'user123',
        );

        final refImageData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final partImageData = Uint8List.fromList([6, 7, 8, 9, 10]);

        final updatedRecord = record.withStoredImages(
          referenceImageData: refImageData,
          partImageData: partImageData,
          compressionLevel: 'high',
        );

        expect(updatedRecord.storedImages, isNotNull);
        expect(updatedRecord.storedImages!.referenceImageData, equals(refImageData));
        expect(updatedRecord.storedImages!.partImageData, equals(partImageData));
        expect(updatedRecord.storedImages!.compressionLevel, equals('high'));
        expect(updatedRecord.storedImages!.totalSize, equals(10));
      });

      test('should calculate duration correctly', () {
        final startTime = DateTime.now();
        
        final record = EnhancedAnalysisRecord.createNew(
          referenceImagePath: '/path/to/reference.jpg',
          partImagePath: '/path/to/part.jpg',
          userId: 'user123',
        );

        // Simulate some processing time
        final endTime = startTime.add(const Duration(seconds: 30));
        
        // Mock completed record
        final completedRecord = record._copyWith(
          completedAt: endTime,
        );

        expect(completedRecord.totalDuration.inSeconds, greaterThanOrEqualTo(30));
      });

      test('should handle error states correctly', () {
        final record = EnhancedAnalysisRecord.createNew(
          referenceImagePath: '/path/to/reference.jpg',
          partImagePath: '/path/to/part.jpg',
          userId: 'user123',
        );

        final errorRecord = record.withError('Network connection failed');

        expect(errorRecord.status, equals(AnalysisStatus.failed));
        expect(errorRecord.events.any((e) => e.type == AnalysisEventType.error), isTrue);
        expect(errorRecord.isCompleted, isFalse);
      });
    });

    group('Integration Tests', () {
      test('should work with complete analysis workflow', () {
        // 1. Create new analysis record
        var record = EnhancedAnalysisRecord.createNew(
          referenceImagePath: '/path/to/reference.jpg',
          partImagePath: '/path/to/part.jpg',
          userId: 'user123',
        );

        expect(record.status, equals(AnalysisStatus.initialized));

        // 2. Add quality analysis
        record = record.withQualityAnalysis(
          referenceQuality: moderateQualityMetrics,
          partQuality: moderateQualityMetrics,
        );

        expect(record.status, equals(AnalysisStatus.qualityAnalyzed));

        // 3. Calculate confidence score
        final confidence = EnhancedConfidenceScore.calculate(
          referenceQuality: moderateQualityMetrics,
          partQuality: moderateQualityMetrics,
          complexity: AnalysisComplexity.moderate,
          history: null,
          contextualData: {'hasReferenceModel': true},
        );

        final recommendation = ActionRecommendation.generateRecommendations(
          referenceQuality: moderateQualityMetrics,
          partQuality: moderateQualityMetrics,
          confidenceScore: confidence,
          issues: moderateQualityMetrics.getQualityIssues(),
        );

        record = record.withConfidenceScore(
          confidence: confidence,
          actionRecommendation: recommendation,
        );

        expect(record.status, equals(AnalysisStatus.confidenceCalculated));

        // 4. Add user feedback
        final feedback = AnalysisFeedback.createMixed(
          analysisId: record.id,
          accuracyRating: AccuracyRating.good,
          partialIssues: ['Minor detection issue'],
          suggestions: [FeedbackSuggestion.imageQuality('Better lighting')],
          reportedConfidence: confidence.overallConfidence,
          actualConfidence: 0.7,
        );

        record = record.withUserFeedback(feedback);

        expect(record.status, equals(AnalysisStatus.feedbackReceived));
        expect(record.hasFeedback, isTrue);
        expect(record.confidenceAccuracy, greaterThan(0.0));

        // 5. Verify complete workflow
        expect(record.events.length, greaterThanOrEqualTo(4));
        expect(record.overallQualityScore, greaterThan(0.0));
        expect(record.getImprovementSuggestions(), isNotEmpty);
      });

      test('should handle low quality scenario correctly', () {
        var record = EnhancedAnalysisRecord.createNew(
          referenceImagePath: '/path/to/reference.jpg',
          partImagePath: '/path/to/part.jpg',
          userId: 'user123',
        );

        record = record.withQualityAnalysis(
          referenceQuality: lowQualityMetrics,
          partQuality: lowQualityMetrics,
        );

        final confidence = EnhancedConfidenceScore.calculate(
          referenceQuality: lowQualityMetrics,
          partQuality: lowQualityMetrics,
          complexity: AnalysisComplexity.complex,
          history: null,
          contextualData: {
            'hasReflectiveSurfaces': true,
            'poorAngle': true,
          },
        );

        expect(confidence.requiresHumanReview, isTrue);
        expect(confidence.shouldShowWarnings, isTrue);

        final issues = lowQualityMetrics.getQualityIssues();
        expect(issues, isNotEmpty);

        final recommendation = ActionRecommendation.generateRecommendations(
          referenceQuality: lowQualityMetrics,
          partQuality: lowQualityMetrics,
          confidenceScore: confidence,
          issues: issues,
        );

        expect(recommendation.priority, anyOf([
          ActionPriority.high,
          ActionPriority.critical
        ]));
        expect(recommendation.isActionable, isTrue);
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle null values gracefully', () {
        final confidence = EnhancedConfidenceScore.calculate(
          referenceQuality: moderateQualityMetrics,
          partQuality: moderateQualityMetrics,
          complexity: AnalysisComplexity.simple,
          history: null, // Null history should not cause issues
          contextualData: {}, // Empty context should not cause issues
        );

        expect(confidence.overallConfidence, greaterThan(0.0));
        expect(confidence.overallConfidence, lessThan(1.0));
      });

      test('should handle extreme contextual data', () {
        final extremeContext = {
          'hasReferenceModel': true,
          'goodLightingConditions': true,
          'stableEnvironment': true,
          'hasReflectiveSurfaces': true,
          'poorAngle': true,
          'backgroundNoise': true,
        };

        final confidence = EnhancedConfidenceScore.calculate(
          referenceQuality: moderateQualityMetrics,
          partQuality: moderateQualityMetrics,
          complexity: AnalysisComplexity.moderate,
          history: null,
          contextualData: extremeContext,
        );

        // Should handle conflicting context gracefully
        expect(confidence.contextualScore, greaterThan(0.0));
        expect(confidence.contextualScore, lessThan(1.0));
      });

      test('should handle empty issues list', () {
        final recommendation = ActionRecommendation.generateRecommendations(
          referenceQuality: highQualityMetrics,
          partQuality: highQualityMetrics,
          confidenceScore: EnhancedConfidenceScore.calculate(
            referenceQuality: highQualityMetrics,
            partQuality: highQualityMetrics,
            complexity: AnalysisComplexity.simple,
            history: null,
            contextualData: {},
          ),
          issues: [], // Empty issues list
        );

        expect(recommendation.type, anyOf([
          RecommendationType.proceed,
          RecommendationType.reviewSettings
        ]));
      });
    });
  });
}