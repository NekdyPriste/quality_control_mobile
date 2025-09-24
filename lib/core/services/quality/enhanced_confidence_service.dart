import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quality/image_quality_metrics.dart';
import '../../models/quality/enhanced_confidence_score.dart';
import '../../models/quality/pre_analysis_result.dart';
import '../../models/comparison_result.dart';
import 'image_quality_analyzer_service.dart';

final enhancedConfidenceServiceProvider = Provider<EnhancedConfidenceService>((ref) {
  return EnhancedConfidenceService(
    imageQualityAnalyzer: ImageQualityAnalyzerService(),
  );
});

class EnhancedConfidenceService {
  final ImageQualityAnalyzerService _imageQualityAnalyzer;

  EnhancedConfidenceService({
    required ImageQualityAnalyzerService imageQualityAnalyzer,
  }) : _imageQualityAnalyzer = imageQualityAnalyzer;

  /// Provede kompletní pre-analýzu kvality snímků před odesláním do AI
  Future<PreAnalysisResult> evaluateImageQuality({
    required File referenceImage,
    required File partImage,
    Map<String, dynamic>? contextualData,
  }) async {
    return await _imageQualityAnalyzer.evaluateBeforeAIAnalysis(
      referenceImage: referenceImage,
      partImage: partImage,
    );
  }

  /// Vypočítá enhanced confidence score na základě různých faktorů
  Future<EnhancedConfidenceScore> calculateConfidenceScore({
    required ImageQualityMetrics referenceQuality,
    required ImageQualityMetrics partQuality,
    required AnalysisComplexity complexity,
    required ComparisonResult? preliminaryResult,
    Map<String, dynamic>? contextualData,
    ModelPerformanceHistory? history,
  }) async {
    // Určí složitost analýzy na základě preliminary result
    final adjustedComplexity = _adjustComplexityBasedOnPreliminaryResult(
      complexity,
      preliminaryResult,
    );

    // Připraví kontextuální data
    final contextData = _prepareContextualData(
      contextualData ?? {},
      preliminaryResult,
    );

    // Vypočítá enhanced confidence score
    return EnhancedConfidenceScore.calculate(
      referenceQuality: referenceQuality,
      partQuality: partQuality,
      complexity: adjustedComplexity,
      history: history,
      contextualData: contextData,
    );
  }

  /// Kombinuje výsledky image quality a AI analýzy pro finální confidence
  Future<EnhancedConfidenceScore> calculateFinalConfidence({
    required PreAnalysisResult preAnalysis,
    required ComparisonResult aiResult,
    required AnalysisComplexity complexity,
    ModelPerformanceHistory? history,
  }) async {
    if (preAnalysis.referenceQuality == null || 
        preAnalysis.partQuality == null) {
      throw Exception('Pre-analysis must contain quality metrics');
    }

    // Adjustuje complexity na základě AI výsledků
    final adjustedComplexity = _determineComplexityFromResults(
      complexity,
      preAnalysis,
      aiResult,
    );

    // Připraví rozšířená kontextuální data
    final contextData = _buildEnhancedContextualData(
      preAnalysis,
      aiResult,
    );

    return await calculateConfidenceScore(
      referenceQuality: preAnalysis.referenceQuality!,
      partQuality: preAnalysis.partQuality!,
      complexity: adjustedComplexity,
      preliminaryResult: aiResult,
      contextualData: contextData,
      history: history,
    );
  }

  /// Upraví složitost na základě předběžných výsledků
  AnalysisComplexity _adjustComplexityBasedOnPreliminaryResult(
    AnalysisComplexity initialComplexity,
    ComparisonResult? preliminaryResult,
  ) {
    if (preliminaryResult == null) return initialComplexity;

    // Analýza počtu a typu defektů
    final defectCount = preliminaryResult.defectsFound.length;
    final criticalDefects = preliminaryResult.defectsFound
        .where((d) => d.severity == DefectSeverity.critical)
        .length;
    final lowConfidence = preliminaryResult.confidenceScore < 0.6;

    // Adjustuje složitost nahoru při problematických případech
    if (criticalDefects > 2 || (defectCount > 5 && lowConfidence)) {
      return AnalysisComplexity.extreme;
    } else if (criticalDefects > 0 || defectCount > 3) {
      return AnalysisComplexity.complex;
    } else if (defectCount > 1 || lowConfidence) {
      return AnalysisComplexity.moderate;
    }

    return initialComplexity;
  }

  /// Připraví kontextuální data pro confidence calculation
  Map<String, dynamic> _prepareContextualData(
    Map<String, dynamic> baseContext,
    ComparisonResult? preliminaryResult,
  ) {
    final contextData = Map<String, dynamic>.from(baseContext);

    // Základní kontextuální faktory
    contextData['hasReferenceModel'] = true;
    contextData['goodLightingConditions'] = baseContext['goodLighting'] ?? true;
    contextData['stableEnvironment'] = baseContext['stable'] ?? true;
    contextData['hasReflectiveSurfaces'] = baseContext['reflective'] ?? false;
    contextData['poorAngle'] = baseContext['badAngle'] ?? false;
    contextData['backgroundNoise'] = baseContext['noisyBackground'] ?? false;

    // Faktory na základě preliminary result
    if (preliminaryResult != null) {
      contextData['aiConfidenceLevel'] = _categorizeAIConfidence(
        preliminaryResult.confidenceScore,
      );
      contextData['defectComplexity'] = _categorizeDefectComplexity(
        preliminaryResult.defectsFound,
      );
      contextData['qualityStatus'] = preliminaryResult.overallQuality.name;
    }

    return contextData;
  }

  /// Určí finální complexity na základě všech dostupných dat
  AnalysisComplexity _determineComplexityFromResults(
    AnalysisComplexity baseComplexity,
    PreAnalysisResult preAnalysis,
    ComparisonResult aiResult,
  ) {
    int complexityScore = baseComplexity.index;

    // Faktory zvyšující složitost
    if (preAnalysis.hasCriticalIssues) complexityScore += 1;
    if (aiResult.confidenceScore < 0.5) complexityScore += 1;
    if (aiResult.defectsFound.length > 3) complexityScore += 1;
    if (aiResult.defectsFound.any((d) => d.severity == DefectSeverity.critical)) {
      complexityScore += 2;
    }

    // Faktory snižující složitost
    if (preAnalysis.expectedConfidence > 0.8) complexityScore -= 1;
    if (aiResult.overallQuality == QualityStatus.pass && 
        aiResult.defectsFound.isEmpty) {
      complexityScore -= 1;
    }

    // Clamp to valid range
    complexityScore = complexityScore.clamp(0, AnalysisComplexity.values.length - 1);

    return AnalysisComplexity.values[complexityScore];
  }

  /// Vytvoří rozšířená kontextuální data kombinující pre-analýzu a AI výsledky
  Map<String, dynamic> _buildEnhancedContextualData(
    PreAnalysisResult preAnalysis,
    ComparisonResult aiResult,
  ) {
    return {
      // Pre-analysis data
      'preAnalysisDecision': preAnalysis.decision.name,
      'expectedConfidence': preAnalysis.expectedConfidence,
      'imageQualityIssues': preAnalysis.issues.length,
      'hasQualityWarnings': preAnalysis.hasWarnings,
      
      // AI analysis data
      'aiConfidence': aiResult.confidenceScore,
      'defectCount': aiResult.defectsFound.length,
      'qualityStatus': aiResult.overallQuality.name,
      'hasCriticalDefects': aiResult.defectsFound
          .any((d) => d.severity == DefectSeverity.critical),
      
      // Combined factors
      'confidenceAlignment': _calculateConfidenceAlignment(
        preAnalysis.expectedConfidence,
        aiResult.confidenceScore,
      ),
      'analysisConsistency': _assessAnalysisConsistency(
        preAnalysis,
        aiResult,
      ),
      
      // Environmental factors
      'hasReferenceModel': true,
      'goodLightingConditions': _assessLightingFromQuality(preAnalysis),
      'stableEnvironment': true,
      'hasReflectiveSurfaces': false,
      'poorAngle': _assessAngleFromQuality(preAnalysis),
      'backgroundNoise': false,
    };
  }

  /// Kategorizes AI confidence level
  String _categorizeAIConfidence(double confidence) {
    if (confidence >= 0.8) return 'high';
    if (confidence >= 0.6) return 'medium';
    if (confidence >= 0.4) return 'low';
    return 'very_low';
  }

  /// Kategorizes defect complexity
  String _categorizeDefectComplexity(List<Defect> defects) {
    if (defects.isEmpty) return 'none';
    
    final criticalCount = defects.where((d) => d.severity == DefectSeverity.critical).length;
    final majorCount = defects.where((d) => d.severity == DefectSeverity.major).length;
    
    if (criticalCount > 1) return 'extreme';
    if (criticalCount > 0 || majorCount > 2) return 'high';
    if (majorCount > 0 || defects.length > 2) return 'medium';
    return 'low';
  }

  /// Vypočítá alignment mezi expected a actual confidence
  double _calculateConfidenceAlignment(double expected, double actual) {
    final diff = (expected - actual).abs();
    return (1.0 - diff).clamp(0.0, 1.0);
  }

  /// Hodnotí konzistenci mezi pre-analysis a AI výsledky
  double _assessAnalysisConsistency(
    PreAnalysisResult preAnalysis,
    ComparisonResult aiResult,
  ) {
    double consistency = 0.7; // Base score

    // Porovná expected confidence s actual
    final confidenceDiff = (preAnalysis.expectedConfidence - aiResult.confidenceScore).abs();
    consistency += (1.0 - confidenceDiff) * 0.3;

    // Ověří prediction accuracy
    if (preAnalysis.decision == PreAnalysisDecision.rejectAndRetake) {
      // Měl by být problém s kvalitou
      if (aiResult.confidenceScore < 0.6 || aiResult.defectsFound.isNotEmpty) {
        consistency += 0.2;
      } else {
        consistency -= 0.3; // False negative
      }
    } else if (preAnalysis.decision == PreAnalysisDecision.proceed) {
      // Měla by být dobrá kvalita
      if (aiResult.confidenceScore > 0.7 && aiResult.defectsFound.length < 2) {
        consistency += 0.2;
      } else {
        consistency -= 0.2; // False positive
      }
    }

    return consistency.clamp(0.0, 1.0);
  }

  /// Odvozuje kvalitu osvětlení z image quality metrics
  bool _assessLightingFromQuality(PreAnalysisResult preAnalysis) {
    if (preAnalysis.referenceQuality == null || preAnalysis.partQuality == null) {
      return true; // Default assumption
    }

    final avgBrightness = (preAnalysis.referenceQuality!.brightness + 
                          preAnalysis.partQuality!.brightness) / 2;
    final avgContrast = (preAnalysis.referenceQuality!.contrast + 
                        preAnalysis.partQuality!.contrast) / 2;

    return avgBrightness >= 0.4 && avgBrightness <= 0.8 && avgContrast >= 0.3;
  }

  /// Odvozuje kvalitu úhlu z image quality metrics
  bool _assessAngleFromQuality(PreAnalysisResult preAnalysis) {
    if (preAnalysis.referenceQuality == null || preAnalysis.partQuality == null) {
      return false; // Default assumption - good angle
    }

    final avgCoverage = (preAnalysis.referenceQuality!.objectCoverage + 
                        preAnalysis.partQuality!.objectCoverage) / 2;
    final avgEdgeClarity = (preAnalysis.referenceQuality!.edgeClarity + 
                           preAnalysis.partQuality!.edgeClarity) / 2;

    return avgCoverage < 0.4 || avgEdgeClarity < 0.5;
  }

  /// Načte historii výkonnosti modelu (mock implementation)
  Future<ModelPerformanceHistory?> getModelPerformanceHistory() async {
    // V reálné implementaci by se načetla z databáze
    // Pro teď vrací mock data
    return const ModelPerformanceHistory(
      totalAnalyses: 150,
      successfulAnalyses: 127,
      recentAccuracy: 0.85,
      lastUpdated: null, // DateTime.now() místo null v reálné implementaci
    );
  }

  /// Poskytuje doporučení pro zlepšení confidence score
  List<String> getConfidenceImprovementSuggestions(
    EnhancedConfidenceScore confidence,
  ) {
    final suggestions = <String>[];

    for (final factor in confidence.factors) {
      if (factor.score < 0.6) {
        switch (factor.type) {
          case ConfidenceFactorType.imageQuality:
            suggestions.add('Zlepšete kvalitu snímků - použijte lepší osvětlení a ostřejší záběry');
            break;
          case ConfidenceFactorType.modelReliability:
            suggestions.add('Zjednodušte analýzu nebo použijte více referenčních snímků');
            break;
          case ConfidenceFactorType.contextual:
            suggestions.add('Zlepšete podmínky snímání - odstraňte reflexe a zlepšete úhel');
            break;
          case ConfidenceFactorType.historical:
            suggestions.add('Model se stále učí - výsledky se budou zlepšovat s více daty');
            break;
          case ConfidenceFactorType.complexity:
            suggestions.add('Rozdělte složitou analýzu na více jednodušších kroků');
            break;
        }
      }
    }

    return suggestions.isNotEmpty ? suggestions : [
      'Vaše confidence skóre je dobré - pokračujte ve stejné kvalitě snímků'
    ];
  }
}