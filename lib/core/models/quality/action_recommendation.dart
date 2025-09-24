import 'image_quality_metrics.dart';
import 'enhanced_confidence_score.dart';

class ActionRecommendation {
  final RecommendationType type;
  final ActionPriority priority;
  final String title;
  final String description;
  final List<RecommendationStep> steps;
  final EstimatedImprovement expectedImprovement;
  final Duration estimatedTime;
  final List<String> requiredResources;
  final RecommendationCategory category;

  const ActionRecommendation({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.steps,
    required this.expectedImprovement,
    required this.estimatedTime,
    required this.requiredResources,
    required this.category,
  });

  factory ActionRecommendation.generateRecommendations({
    required ImageQualityMetrics referenceQuality,
    required ImageQualityMetrics partQuality,
    required EnhancedConfidenceScore confidenceScore,
    required List<QualityIssue> issues,
  }) {
    final recommendations = <ActionRecommendation>[];

    // Analýza problémů a generování doporučení
    for (final issue in issues) {
      final recommendation = _generateRecommendationForIssue(
        issue,
        referenceQuality,
        partQuality,
        confidenceScore,
      );
      if (recommendation != null) {
        recommendations.add(recommendation);
      }
    }

    // Vrácení nejvýznamnějšího doporučení
    if (recommendations.isNotEmpty) {
      recommendations.sort((a, b) => b.priority.index.compareTo(a.priority.index));
      return recommendations.first;
    }

    // Fallback doporučení
    return ActionRecommendation.defaultRecommendation(confidenceScore);
  }

  static ActionRecommendation? _generateRecommendationForIssue(
    QualityIssue issue,
    ImageQualityMetrics referenceQuality,
    ImageQualityMetrics partQuality,
    EnhancedConfidenceScore confidenceScore,
  ) {
    switch (issue.type) {
      case QualityIssueType.blur:
        return _createBlurRecommendation(issue.severity, confidenceScore);
      
      case QualityIssueType.lighting:
        return _createLightingRecommendation(issue.severity, confidenceScore);
      
      case QualityIssueType.contrast:
        return _createContrastRecommendation(issue.severity, confidenceScore);
      
      case QualityIssueType.noise:
        return _createNoiseRecommendation(issue.severity, confidenceScore);
      
      case QualityIssueType.resolution:
        return _createResolutionRecommendation(issue.severity, confidenceScore);
      
      case QualityIssueType.objectSize:
        return _createObjectSizeRecommendation(issue.severity, confidenceScore);
    }
  }

  static ActionRecommendation _createBlurRecommendation(
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
        RecommendationStep(
          order: 3,
          action: 'Stabilizujte kameru',
          details: 'Opřete lokty o stůl nebo použijte obě ruce',
          estimatedTime: Duration(seconds: 10),
        ),
        RecommendationStep(
          order: 4,
          action: 'Pořiďte nový snímek',
          details: 'Držte kameru pevně a vyčkejte na ostrý obraz',
          estimatedTime: Duration(seconds: 15),
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

  static ActionRecommendation _createLightingRecommendation(
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
        RecommendationStep(
          order: 2,
          action: 'Zapněte světla v místnosti',
          details: 'Použijte několik zdrojů světla pro rovnoměrné osvětlení',
          estimatedTime: Duration(seconds: 15),
        ),
        RecommendationStep(
          order: 3,
          action: 'Vyhněte se stínům',
          details: 'Umístěte objekt tak, aby na něj nepadaly ostré stíny',
          estimatedTime: Duration(seconds: 45),
        ),
      ],
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.25,
        qualityIncrease: 0.35,
        successProbability: 0.80,
      ),
      estimatedTime: Duration(minutes: 2),
      requiredResources: ['Dodatečné osvětlení', 'Vhodné místo'],
      category: RecommendationCategory.environment,
    );
  }

  static ActionRecommendation _createContrastRecommendation(
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
        RecommendationStep(
          order: 2,
          action: 'Upravte úhel osvětlení',
          details: 'Změňte směr světla pro lepší kontrast',
          estimatedTime: Duration(seconds: 30),
        ),
      ],
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.20,
        qualityIncrease: 0.30,
        successProbability: 0.75,
      ),
      estimatedTime: Duration(minutes: 2),
      requiredResources: ['Kontrastní materiál', 'Nastavitelné osvětlení'],
      category: RecommendationCategory.setup,
    );
  }

  static ActionRecommendation _createNoiseRecommendation(
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
        RecommendationStep(
          order: 2,
          action: 'Použijte hlavní kameru',
          details: 'Vyhněte se digitálnímu přiblížení',
          estimatedTime: Duration(seconds: 5),
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

  static ActionRecommendation _createResolutionRecommendation(
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
        RecommendationStep(
          order: 2,
          action: 'Přibližte se k objektu',
          details: 'Zkraťte vzdálenost pro více detailů',
          estimatedTime: Duration(seconds: 20),
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

  static ActionRecommendation _createObjectSizeRecommendation(
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
        RecommendationStep(
          order: 2,
          action: 'Vycentrujte objekt',
          details: 'Umístěte objekt do středu obrazu',
          estimatedTime: Duration(seconds: 15),
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

  factory ActionRecommendation.defaultRecommendation(
    EnhancedConfidenceScore confidenceScore,
  ) {
    if (confidenceScore.confidenceLevel == ConfidenceLevel.veryHigh) {
      return ActionRecommendation(
        type: RecommendationType.proceed,
        priority: ActionPriority.low,
        title: 'Pokračovat v analýze',
        description: 'Kvalita snímků je vynikající pro AI analýzu',
        steps: [],
        expectedImprovement: EstimatedImprovement(
          confidenceIncrease: 0.0,
          qualityIncrease: 0.0,
          successProbability: 1.0,
        ),
        estimatedTime: Duration.zero,
        requiredResources: [],
        category: RecommendationCategory.analysis,
      );
    }

    return ActionRecommendation(
      type: RecommendationType.reviewSettings,
      priority: ActionPriority.medium,
      title: 'Zkontrolovat nastavení',
      description: 'Obecná kontrola kvality před analýzou',
      steps: [
        RecommendationStep(
          order: 1,
          action: 'Zkontrolujte osvětlení',
          details: 'Ujistěte se, že objekt je dobře osvětlen',
          estimatedTime: Duration(seconds: 30),
        ),
        RecommendationStep(
          order: 2,
          action: 'Ověřte ostrost',
          details: 'Snímky by měly být ostré a čitelné',
          estimatedTime: Duration(seconds: 30),
        ),
      ],
      expectedImprovement: EstimatedImprovement(
        confidenceIncrease: 0.10,
        qualityIncrease: 0.15,
        successProbability: 0.60,
      ),
      estimatedTime: Duration(minutes: 1),
      requiredResources: [],
      category: RecommendationCategory.review,
    );
  }

  bool get isActionable => steps.isNotEmpty;
  bool get isUrgent => priority == ActionPriority.critical;
  bool get hasHighImpact => expectedImprovement.confidenceIncrease >= 0.2;

  factory ActionRecommendation.fromJson(Map<String, dynamic> json) {
    return ActionRecommendation(
      type: RecommendationType.values.firstWhere((e) => e.name == json['type']),
      priority: ActionPriority.values.firstWhere((e) => e.name == json['priority']),
      title: json['title'] as String,
      description: json['description'] as String,
      steps: (json['steps'] as List<dynamic>)
          .map((e) => RecommendationStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      expectedImprovement: EstimatedImprovement.fromJson(json['expectedImprovement'] as Map<String, dynamic>),
      estimatedTime: Duration(milliseconds: json['estimatedTimeMs'] as int),
      requiredResources: (json['requiredResources'] as List<dynamic>).cast<String>(),
      category: RecommendationCategory.values.firstWhere((e) => e.name == json['category']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'priority': priority.name,
      'title': title,
      'description': description,
      'steps': steps.map((e) => e.toJson()).toList(),
      'expectedImprovement': expectedImprovement.toJson(),
      'estimatedTimeMs': estimatedTime.inMilliseconds,
      'requiredResources': requiredResources,
      'category': category.name,
    };
  }
}

enum RecommendationType {
  retakePhoto,        // Pořídit nový snímek
  improveConditions,  // Zlepšit podmínky
  adjustSettings,     // Upravit nastavení
  changeBackground,   // Změnit pozadí
  repositionCamera,   // Přemístit kameru
  reviewSettings,     // Zkontrolovat nastavení
  proceed            // Pokračovat v analýze
}

enum ActionPriority {
  low,       // Nízká priorita
  medium,    // Střední priorita  
  high,      // Vysoká priorita
  critical   // Kritická priorita
}

enum RecommendationCategory {
  imageCapture,  // Pořizování snímků
  environment,   // Prostředí
  setup,         // Nastavení scény
  technical,     // Technické aspekty
  positioning,   // Pozicování
  analysis,      // Analýza
  review        // Kontrola
}

class RecommendationStep {
  final int order;
  final String action;
  final String details;
  final Duration estimatedTime;

  const RecommendationStep({
    required this.order,
    required this.action,
    required this.details,
    required this.estimatedTime,
  });

  factory RecommendationStep.fromJson(Map<String, dynamic> json) {
    return RecommendationStep(
      order: json['order'] as int,
      action: json['action'] as String,
      details: json['details'] as String,
      estimatedTime: Duration(milliseconds: json['estimatedTimeMs'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'action': action,
      'details': details,
      'estimatedTimeMs': estimatedTime.inMilliseconds,
    };
  }
}

class EstimatedImprovement {
  final double confidenceIncrease;  // 0.0-1.0 očekávaný nárůst jistoty
  final double qualityIncrease;     // 0.0-1.0 očekávaný nárůst kvality
  final double successProbability;  // 0.0-1.0 pravděpodobnost úspěchu

  const EstimatedImprovement({
    required this.confidenceIncrease,
    required this.qualityIncrease,
    required this.successProbability,
  });

  factory EstimatedImprovement.fromJson(Map<String, dynamic> json) {
    return EstimatedImprovement(
      confidenceIncrease: (json['confidenceIncrease'] as num).toDouble(),
      qualityIncrease: (json['qualityIncrease'] as num).toDouble(),
      successProbability: (json['successProbability'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'confidenceIncrease': confidenceIncrease,
      'qualityIncrease': qualityIncrease,
      'successProbability': successProbability,
    };
  }
}