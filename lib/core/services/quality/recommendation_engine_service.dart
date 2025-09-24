import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quality/image_quality_metrics.dart';
import '../../models/quality/enhanced_confidence_score.dart';
import '../../models/quality/action_recommendation.dart';
import '../../models/quality/pre_analysis_result.dart';
import '../../models/comparison_result.dart';
import '../../models/defect.dart';

final recommendationEngineServiceProvider = Provider<RecommendationEngineService>((ref) {
  return RecommendationEngineService();
});

class RecommendationEngineService {
  
  /// Generuje smart doporučení na základě analýzy kvality a confidence score
  Future<List<ActionRecommendation>> generateRecommendations({
    required ImageQualityMetrics referenceQuality,
    required ImageQualityMetrics partQuality,
    required EnhancedConfidenceScore confidenceScore,
    PreAnalysisResult? preAnalysisResult,
    ComparisonResult? aiResult,
  }) async {
    final recommendations = <ActionRecommendation>[];

    // 1. Doporučení na základě image quality issues
    final qualityRecommendations = await _generateQualityRecommendations(
      referenceQuality,
      partQuality,
      confidenceScore,
    );
    recommendations.addAll(qualityRecommendations);

    // 2. Doporučení na základě confidence score
    final confidenceRecommendations = await _generateConfidenceRecommendations(
      confidenceScore,
    );
    recommendations.addAll(confidenceRecommendations);

    // 3. Doporučení na základě pre-analysis
    if (preAnalysisResult != null) {
      final preAnalysisRecommendations = await _generatePreAnalysisRecommendations(
        preAnalysisResult,
      );
      recommendations.addAll(preAnalysisRecommendations);
    }

    // 4. Doporučení na základě AI výsledků
    if (aiResult != null) {
      final aiRecommendations = await _generateAIResultRecommendations(
        aiResult,
        confidenceScore,
      );
      recommendations.addAll(aiRecommendations);
    }

    // Seřadí podle priority a vrátí top doporučení
    return _prioritizeAndFilterRecommendations(recommendations);
  }

  /// Generuje doporučení specificky pro zlepšení image quality
  Future<List<ActionRecommendation>> _generateQualityRecommendations(
    ImageQualityMetrics referenceQuality,
    ImageQualityMetrics partQuality,
    EnhancedConfidenceScore confidenceScore,
  ) async {
    final recommendations = <ActionRecommendation>[];
    final allIssues = <QualityIssue>[];
    
    // Kombinuje problémy z obou snímků
    allIssues.addAll(referenceQuality.getQualityIssues());
    allIssues.addAll(partQuality.getQualityIssues());

    // Skupí problémy podle typu a generuje doporučení
    final issueGroups = _groupIssuesByType(allIssues);
    
    for (final entry in issueGroups.entries) {
      final issueType = entry.key;
      final issues = entry.value;
      final severity = _getHighestSeverity(issues);
      
      final recommendation = await _createRecommendationForIssueType(
        issueType,
        severity,
        issues.length,
        confidenceScore,
      );
      
      if (recommendation != null) {
        recommendations.add(recommendation);
      }
    }

    return recommendations;
  }

  /// Generuje doporučení na základě confidence score faktorů
  Future<List<ActionRecommendation>> _generateConfidenceRecommendations(
    EnhancedConfidenceScore confidenceScore,
  ) async {
    final recommendations = <ActionRecommendation>[];

    // Analyzuje jednotlivé faktory confidence score
    for (final factor in confidenceScore.factors) {
      if (factor.score < 0.6) {
        final recommendation = await _createConfidenceFactorRecommendation(
          factor,
          confidenceScore.overallConfidence,
        );
        
        if (recommendation != null) {
          recommendations.add(recommendation);
        }
      }
    }

    // Overall confidence recommendation
    if (confidenceScore.overallConfidence < 0.5) {
      recommendations.add(_createOverallConfidenceRecommendation(confidenceScore));
    }

    return recommendations;
  }

  /// Generuje doporučení na základě pre-analysis výsledků
  Future<List<ActionRecommendation>> _generatePreAnalysisRecommendations(
    PreAnalysisResult preAnalysisResult,
  ) async {
    final recommendations = <ActionRecommendation>[];

    switch (preAnalysisResult.decision) {
      case PreAnalysisDecision.rejectAndRetake:
        recommendations.add(_createRetakeRecommendation(
          preAnalysisResult,
          ActionPriority.critical,
        ));
        break;
        
      case PreAnalysisDecision.optimizeFirst:
        recommendations.add(_createOptimizeFirstRecommendation(
          preAnalysisResult,
        ));
        break;
        
      case PreAnalysisDecision.proceedWithWarning:
        recommendations.add(_createWarningRecommendation(
          preAnalysisResult,
        ));
        break;
        
      case PreAnalysisDecision.proceed:
        // Žádné doporučení - kvalita je dobrá
        break;
    }

    return recommendations;
  }

  /// Generuje doporučení na základě AI analysis výsledků
  Future<List<ActionRecommendation>> _generateAIResultRecommendations(
    ComparisonResult aiResult,
    EnhancedConfidenceScore confidenceScore,
  ) async {
    final recommendations = <ActionRecommendation>[];

    // Doporučení pro nízkou AI confidence
    if (aiResult.confidenceScore < 0.6) {
      recommendations.add(_createLowAIConfidenceRecommendation(
        aiResult,
        confidenceScore,
      ));
    }

    // Doporučení pro detekované defekty
    if (aiResult.defectsFound.isNotEmpty) {
      recommendations.add(_createDefectHandlingRecommendation(
        aiResult.defectsFound,
        aiResult.overallQuality,
      ));
    }

    // Doporučení pro Quality Status
    if (aiResult.overallQuality == QualityStatus.fail) {
      recommendations.add(_createQualityFailureRecommendation(
        aiResult,
        confidenceScore,
      ));
    }

    return recommendations;
  }

  /// Vytvoří doporučení pro konkrétní typ quality issue
  Future<ActionRecommendation?> _createRecommendationForIssueType(
    QualityIssueType issueType,
    IssueSeverity severity,
    int issueCount,
    EnhancedConfidenceScore confidenceScore,
  ) async {
    switch (issueType) {
      case QualityIssueType.blur:
        return _createBlurRecommendationForService(
          severity,
          confidenceScore,
        );
      case QualityIssueType.lighting:
        return _createLightingRecommendationForService(
          severity,
          confidenceScore,
        );
      case QualityIssueType.contrast:
        return _createContrastRecommendationForService(
          severity,
          confidenceScore,
        );
      case QualityIssueType.noise:
        return _createNoiseRecommendationForService(
          severity,
          confidenceScore,
        );
      case QualityIssueType.resolution:
        return _createResolutionRecommendationForService(
          severity,
          confidenceScore,
        );
      case QualityIssueType.objectSize:
        return _createObjectSizeRecommendationForService(
          severity,
          confidenceScore,
        );
    }
  }

  /// Vytvoří doporučení pro confidence factor
  Future<ActionRecommendation?> _createConfidenceFactorRecommendation(
    ConfidenceFactor factor,
    double overallConfidence,
  ) async {
    switch (factor.type) {
      case ConfidenceFactorType.imageQuality:
        return ActionRecommendation(
          type: RecommendationType.improveConditions,
          priority: ActionPriority.high,
          title: 'Zlepšit kvalitu snímků',
          description: factor.description,
          steps: [
            RecommendationStep(
              order: 1,
              action: 'Zkontrolujte ostrost snímků',
              details: 'Ujistěte se, že objekty jsou ostré a čitelné',
              estimatedTime: Duration(seconds: 30),
            ),
            RecommendationStep(
              order: 2,
              action: 'Zlepšete osvětlení',
              details: 'Použijte rovnoměrné osvětlení bez stínů',
              estimatedTime: Duration(minutes: 1),
            ),
          ],
          expectedImprovement: EstimatedImprovement(
            confidenceIncrease: 1.0 - factor.score,
            qualityIncrease: 0.3,
            successProbability: 0.8,
          ),
          estimatedTime: Duration(minutes: 2),
          requiredResources: ['Dobré osvětlení', 'Stabilní ruce'],
          category: RecommendationCategory.imageCapture,
        );

      case ConfidenceFactorType.contextual:
        return ActionRecommendation(
          type: RecommendationType.changeBackground,
          priority: ActionPriority.medium,
          title: 'Zlepšit podmínky snímání',
          description: 'Optimalizujte prostředí pro lepší výsledky',
          steps: [
            RecommendationStep(
              order: 1,
              action: 'Upravte pozadí',
              details: 'Použijte kontrastní, jednoduché pozadí',
              estimatedTime: Duration(seconds: 45),
            ),
            RecommendationStep(
              order: 2,
              action: 'Minimalizujte reflexe',
              details: 'Odstraňte lesklé povrchy z okolí',
              estimatedTime: Duration(seconds: 30),
            ),
          ],
          expectedImprovement: EstimatedImprovement(
            confidenceIncrease: (1.0 - factor.score) * 0.7,
            qualityIncrease: 0.2,
            successProbability: 0.75,
          ),
          estimatedTime: Duration(minutes: 2),
          requiredResources: ['Kontrastní pozadí'],
          category: RecommendationCategory.environment,
        );

      case ConfidenceFactorType.complexity:
        return ActionRecommendation(
          type: RecommendationType.reviewSettings,
          priority: ActionPriority.low,
          title: 'Zjednodušit analýzu',
          description: 'Rozdělte složitou analýzu na jednodušší části',
          steps: [
            RecommendationStep(
              order: 1,
              action: 'Analyzujte po částech',
              details: 'Zaměřte se na jednotlivé oblasti dílu',
              estimatedTime: Duration(minutes: 2),
            ),
          ],
          expectedImprovement: EstimatedImprovement(
            confidenceIncrease: 0.15,
            qualityIncrease: 0.1,
            successProbability: 0.9,
          ),
          estimatedTime: Duration(minutes: 3),
          requiredResources: [],
          category: RecommendationCategory.analysis,
        );

      case ConfidenceFactorType.modelReliability:
      case ConfidenceFactorType.historical:
        // Tyto faktory uživatel nemůže přímo ovlivnit
        return null;
    }
  }

  ActionRecommendation _createOverallConfidenceRecommendation(
    EnhancedConfidenceScore confidenceScore,
  ) {
    return ActionRecommendation(
      type: RecommendationType.reviewSettings,
      priority: ActionPriority.high,
      title: 'Zvýšit celkovou jistotu analýzy',
      description: 'Nízká jistota může vést k nepřesným výsledkům',
      steps: [
        RecommendationStep(
          order: 1,
          action: 'Zkontrolujte všechny aspekty kvality',
          details: 'Systematicky projděte osvětlení, ostrost a kompozici',
          estimatedTime: Duration(minutes: 2),
        ),
        RecommendationStep(
          order: 2,
          action: 'Zvažte nové snímky',
          details: 'Při trvale nízké jistotě pořiďte snímky znovu',
          estimatedTime: Duration(minutes: 3),
        ),
      ],
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.4,
        qualityIncrease: 0.3,
        successProbability: 0.7,
      ),
      estimatedTime: Duration(minutes: 5),
      requiredResources: ['Čas na kontrolu'],
      category: RecommendationCategory.review,
    );
  }

  ActionRecommendation _createRetakeRecommendation(
    PreAnalysisResult preAnalysisResult,
    ActionPriority priority,
  ) {
    return ActionRecommendation(
      type: RecommendationType.retakePhoto,
      priority: priority,
      title: 'Pořídit nové snímky',
      description: preAnalysisResult.reason,
      steps: preAnalysisResult.recommendations.toList().asMap().entries.map((entry) {
        return RecommendationStep(
          order: entry.key + 1,
          action: entry.value,
          details: 'Následujte toto doporučení před novým snímkem',
          estimatedTime: Duration(seconds: 45),
        );
      }).toList(),
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.5,
        qualityIncrease: 0.6,
        successProbability: 0.85,
      ),
      estimatedTime: Duration(minutes: 3),
      requiredResources: ['Nové snímky'],
      category: RecommendationCategory.imageCapture,
    );
  }

  ActionRecommendation _createOptimizeFirstRecommendation(
    PreAnalysisResult preAnalysisResult,
  ) {
    return ActionRecommendation(
      type: RecommendationType.improveConditions,
      priority: ActionPriority.medium,
      title: 'Optimalizovat před analýzou',
      description: 'Zlepšení podmínek povede k přesnějším výsledkům',
      steps: preAnalysisResult.recommendations.take(3).toList().asMap().entries.map((entry) {
        return RecommendationStep(
          order: entry.key + 1,
          action: entry.value,
          details: 'Implementujte toto zlepšení',
          estimatedTime: Duration(seconds: 30),
        );
      }).toList(),
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.25,
        qualityIncrease: 0.3,
        successProbability: 0.8,
      ),
      estimatedTime: Duration(minutes: 2),
      requiredResources: ['Optimalizace prostředí'],
      category: RecommendationCategory.setup,
    );
  }

  ActionRecommendation _createWarningRecommendation(
    PreAnalysisResult preAnalysisResult,
  ) {
    return ActionRecommendation(
      type: RecommendationType.reviewSettings,
      priority: ActionPriority.low,
      title: 'Zvážit zlepšení kvality',
      description: 'Analýza je možná, ale výsledky mohou být méně přesné',
      steps: preAnalysisResult.recommendations.take(2).toList().asMap().entries.map((entry) {
        return RecommendationStep(
          order: entry.key + 1,
          action: entry.value,
          details: 'Volitelné zlepšení pro lepší výsledky',
          estimatedTime: Duration(seconds: 20),
        );
      }).toList(),
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.15,
        qualityIncrease: 0.2,
        successProbability: 0.7,
      ),
      estimatedTime: Duration(minutes: 1),
      requiredResources: [],
      category: RecommendationCategory.review,
    );
  }

  ActionRecommendation _createLowAIConfidenceRecommendation(
    ComparisonResult aiResult,
    EnhancedConfidenceScore confidenceScore,
  ) {
    return ActionRecommendation(
      type: RecommendationType.reviewSettings,
      priority: ActionPriority.high,
      title: 'Ověřit výsledky analýzy',
      description: 'AI má nízkou jistotu ve svých výsledcích',
      steps: [
        RecommendationStep(
          order: 1,
          action: 'Zkontrolujte výsledky manuálně',
          details: 'Ověřte si nalezené defekty vlastním pohledem',
          estimatedTime: Duration(minutes: 2),
        ),
        RecommendationStep(
          order: 2,
          action: 'Zvažte nové snímky',
          details: 'Pro vyšší jistotu pořiďte snímky z jiného úhlu',
          estimatedTime: Duration(minutes: 1),
        ),
      ],
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.3,
        qualityIncrease: 0.2,
        successProbability: 0.8,
      ),
      estimatedTime: Duration(minutes: 3),
      requiredResources: ['Manuální kontrola'],
      category: RecommendationCategory.analysis,
    );
  }

  ActionRecommendation _createDefectHandlingRecommendation(
    List<Defect> defects,
    QualityStatus overallQuality,
  ) {
    final criticalDefects = defects.where((d) => d.severity == DefectSeverity.critical).length;
    final majorDefects = defects.where((d) => d.severity == DefectSeverity.major).length;

    ActionPriority priority;
    if (criticalDefects > 0) {
      priority = ActionPriority.critical;
    } else if (majorDefects > 0) {
      priority = ActionPriority.high;
    } else {
      priority = ActionPriority.medium;
    }

    return ActionRecommendation(
      type: RecommendationType.reviewSettings,
      priority: priority,
      title: 'Zpracovat nalezené defekty',
      description: 'Nalezeno ${defects.length} defektů vyžadujících pozornost',
      steps: [
        RecommendationStep(
          order: 1,
          action: 'Zkontrolujte kritické defekty',
          details: 'Zaměřte se na defekty označené jako kritické',
          estimatedTime: Duration(minutes: 2),
        ),
        if (overallQuality == QualityStatus.fail)
          RecommendationStep(
            order: 2,
            action: 'Díl nevyhovuje standardům',
            details: 'Zvažte opravu nebo výměnu dílu',
            estimatedTime: Duration(minutes: 5),
          ),
      ],
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.1,
        qualityIncrease: 0.8,
        successProbability: 1.0,
      ),
      estimatedTime: Duration(minutes: criticalDefects > 0 ? 10 : 5),
      requiredResources: ['Defect handling protocol'],
      category: RecommendationCategory.analysis,
    );
  }

  ActionRecommendation _createQualityFailureRecommendation(
    ComparisonResult aiResult,
    EnhancedConfidenceScore confidenceScore,
  ) {
    return ActionRecommendation(
      type: RecommendationType.reviewSettings,
      priority: ActionPriority.critical,
      title: 'Díl nevyhovuje kvalitě',
      description: 'AI analýza označila díl jako nevyhovující',
      steps: [
        RecommendationStep(
          order: 1,
          action: 'Proveďte detailní kontrolu',
          details: 'Ověřte všechny nalezené problémy',
          estimatedTime: Duration(minutes: 5),
        ),
        RecommendationStep(
          order: 2,
          action: 'Dokumentujte defekty',
          details: 'Zaznamenejte všechny problémy pro další zpracování',
          estimatedTime: Duration(minutes: 3),
        ),
        RecommendationStep(
          order: 3,
          action: 'Rozhodněte o dalším postupu',
          details: 'Oprava, výměna nebo další hodnocení',
          estimatedTime: Duration(minutes: 2),
        ),
      ],
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.0,
        qualityIncrease: 0.9,
        successProbability: 1.0,
      ),
      estimatedTime: Duration(minutes: 10),
      requiredResources: ['Quality control protocol'],
      category: RecommendationCategory.analysis,
    );
  }

  /// Pomocné metody pro groupování a prioritizaci
  Map<QualityIssueType, List<QualityIssue>> _groupIssuesByType(
    List<QualityIssue> issues,
  ) {
    final groups = <QualityIssueType, List<QualityIssue>>{};
    
    for (final issue in issues) {
      groups.putIfAbsent(issue.type, () => []).add(issue);
    }
    
    return groups;
  }

  IssueSeverity _getHighestSeverity(List<QualityIssue> issues) {
    IssueSeverity highest = IssueSeverity.minor;
    
    for (final issue in issues) {
      if (issue.severity.index > highest.index) {
        highest = issue.severity;
      }
    }
    
    return highest;
  }

  /// Prioritizuje a filtruje doporučení
  List<ActionRecommendation> _prioritizeAndFilterRecommendations(
    List<ActionRecommendation> recommendations,
  ) {
    // Odstraní duplikáty podle typu
    final uniqueRecommendations = <RecommendationType, ActionRecommendation>{};
    
    for (final rec in recommendations) {
      final existing = uniqueRecommendations[rec.type];
      if (existing == null || rec.priority.index > existing.priority.index) {
        uniqueRecommendations[rec.type] = rec;
      }
    }

    // Seřadí podle priority
    final sorted = uniqueRecommendations.values.toList();
    sorted.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    // Vrátí top 5 doporučení
    return sorted.take(5).toList();
  }

  // Service-specific recommendation creation methods
  ActionRecommendation? _createBlurRecommendationForService(
    IssueSeverity severity,
    EnhancedConfidenceScore confidenceScore,
  ) {
    final priority = severity == IssueSeverity.critical 
        ? ActionPriority.critical 
        : severity == IssueSeverity.major 
            ? ActionPriority.high 
            : ActionPriority.medium;

    return ActionRecommendation(
      type: RecommendationType.retakePhoto,
      priority: priority,
      title: 'Zlepšit ostrost snímku',
      description: 'Snímek je rozmazaný, což výrazně snižuje přesnost AI analýzy',
      steps: [
        RecommendationStep(
          order: 1,
          action: 'Vyčistěte objektiv kamery',
          details: 'Použijte měkký hadřík nebo čistící ubrousek',
          estimatedTime: Duration(seconds: 30),
        ),
        RecommendationStep(
          order: 2,
          action: 'Aktivujte autofocus',
          details: 'Klepněte na objekt na obrazovce před pořízením snímku',
          estimatedTime: Duration(seconds: 5),
        ),
      ],
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.3,
        qualityIncrease: 0.4,
        successProbability: 0.85,
      ),
      estimatedTime: Duration(minutes: 1),
      requiredResources: ['Čistý hadřík', 'Stabilní povrch'],
      category: RecommendationCategory.imageCapture,
    );
  }

  ActionRecommendation? _createLightingRecommendationForService(
    IssueSeverity severity,
    EnhancedConfidenceScore confidenceScore,
  ) {
    return ActionRecommendation(
      type: RecommendationType.improveConditions,
      priority: ActionPriority.high,
      title: 'Zlepšit osvětlení',
      description: 'Nevhodné osvětlení snižuje viditelnost detailů',
      steps: [
        RecommendationStep(
          order: 1,
          action: 'Přemístěte se k oknu',
          details: 'Využijte přirozené světlo, ale vyhněte se přímým paprskům',
          estimatedTime: Duration(seconds: 30),
        ),
      ],
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.25,
        qualityIncrease: 0.35,
        successProbability: 0.80,
      ),
      estimatedTime: Duration(minutes: 2),
      requiredResources: ['Dodatečné osvětlení'],
      category: RecommendationCategory.environment,
    );
  }

  ActionRecommendation? _createContrastRecommendationForService(
    IssueSeverity severity,
    EnhancedConfidenceScore confidenceScore,
  ) {
    return ActionRecommendation(
      type: RecommendationType.changeBackground,
      priority: ActionPriority.medium,
      title: 'Zvýšit kontrast',
      description: 'Nízký kontrast ztěžuje rozlišení detailů objektu',
      steps: [
        RecommendationStep(
          order: 1,
          action: 'Použijte kontrastní pozadí',
          details: 'Světlý objekt na tmavé pozadí nebo naopak',
          estimatedTime: Duration(minutes: 1),
        ),
      ],
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.20,
        qualityIncrease: 0.30,
        successProbability: 0.75,
      ),
      estimatedTime: Duration(minutes: 2),
      requiredResources: ['Kontrastní materiál'],
      category: RecommendationCategory.setup,
    );
  }

  ActionRecommendation? _createNoiseRecommendationForService(
    IssueSeverity severity,
    EnhancedConfidenceScore confidenceScore,
  ) {
    return ActionRecommendation(
      type: RecommendationType.improveConditions,
      priority: ActionPriority.medium,
      title: 'Snížit šum obrazu',
      description: 'Vysoký šum v obraze snižuje přesnost detekce',
      steps: [
        RecommendationStep(
          order: 1,
          action: 'Zlepšete osvětlení',
          details: 'Více světla umožní nižší ISO a méně šumu',
          estimatedTime: Duration(seconds: 45),
        ),
      ],
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.15,
        qualityIncrease: 0.25,
        successProbability: 0.70,
      ),
      estimatedTime: Duration(minutes: 1),
      requiredResources: ['Lepší osvětlení'],
      category: RecommendationCategory.technical,
    );
  }

  ActionRecommendation? _createResolutionRecommendationForService(
    IssueSeverity severity,
    EnhancedConfidenceScore confidenceScore,
  ) {
    return ActionRecommendation(
      type: RecommendationType.adjustSettings,
      priority: ActionPriority.high,
      title: 'Zvýšit rozlišení',
      description: 'Nízké rozlišení omezuje možnosti analýzy detailů',
      steps: [
        RecommendationStep(
          order: 1,
          action: 'Zkontrolujte nastavení kamery',
          details: 'Nastavte nejvyšší dostupné rozlišení',
          estimatedTime: Duration(seconds: 30),
        ),
      ],
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.35,
        qualityIncrease: 0.45,
        successProbability: 0.90,
      ),
      estimatedTime: Duration(seconds: 50),
      requiredResources: ['Nastavení kamery'],
      category: RecommendationCategory.technical,
    );
  }

  ActionRecommendation? _createObjectSizeRecommendationForService(
    IssueSeverity severity,
    EnhancedConfidenceScore confidenceScore,
  ) {
    return ActionRecommendation(
      type: RecommendationType.repositionCamera,
      priority: ActionPriority.high,
      title: 'Zlepšit kompozici snímku',
      description: 'Objekt zabírá málo prostoru, což ztěžuje analýzu',
      steps: [
        RecommendationStep(
          order: 1,
          action: 'Přibližte kameru k objektu',
          details: 'Objekt by měl zabírat alespoň 50% plochy snímku',
          estimatedTime: Duration(seconds: 30),
        ),
      ],
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.25,
        qualityIncrease: 0.30,
        successProbability: 0.85,
      ),
      estimatedTime: Duration(seconds: 45),
      requiredResources: [],
      category: RecommendationCategory.positioning,
    );
  }
}