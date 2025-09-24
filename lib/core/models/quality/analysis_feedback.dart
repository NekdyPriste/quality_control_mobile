
class AnalysisFeedback {
  final String analysisId;
  final DateTime timestamp;
  final FeedbackType type;
  final UserSatisfaction satisfaction;
  final AccuracyRating accuracyRating;
  final String? userComments;
  final List<String> reportedIssues;
  final List<FeedbackSuggestion> suggestions;
  final ConfidenceValidation confidenceValidation;
  final QualityAssessmentFeedback qualityFeedback;

  const AnalysisFeedback({
    required this.analysisId,
    required this.timestamp,
    required this.type,
    required this.satisfaction,
    required this.accuracyRating,
    this.userComments,
    required this.reportedIssues,
    required this.suggestions,
    required this.confidenceValidation,
    required this.qualityFeedback,
  });

  factory AnalysisFeedback.createPositive({
    required String analysisId,
    required AccuracyRating accuracyRating,
    required double reportedConfidence,
    required double actualConfidence,
    String? comments,
  }) {
    return AnalysisFeedback(
      analysisId: analysisId,
      timestamp: DateTime.now(),
      type: FeedbackType.positive,
      satisfaction: _getSatisfactionFromAccuracy(accuracyRating),
      accuracyRating: accuracyRating,
      userComments: comments,
      reportedIssues: [],
      suggestions: [],
      confidenceValidation: ConfidenceValidation(
        reportedConfidence: reportedConfidence,
        actualConfidence: actualConfidence,
        isAccurate: (reportedConfidence - actualConfidence).abs() <= 0.15,
        deviation: (reportedConfidence - actualConfidence).abs(),
      ),
      qualityFeedback: QualityAssessmentFeedback.accurate(),
    );
  }

  factory AnalysisFeedback.createNegative({
    required String analysisId,
    required AccuracyRating accuracyRating,
    required List<String> reportedIssues,
    required double reportedConfidence,
    required double actualConfidence,
    String? comments,
    List<FeedbackSuggestion>? suggestions,
  }) {
    return AnalysisFeedback(
      analysisId: analysisId,
      timestamp: DateTime.now(),
      type: FeedbackType.negative,
      satisfaction: UserSatisfaction.dissatisfied,
      accuracyRating: accuracyRating,
      userComments: comments,
      reportedIssues: reportedIssues,
      suggestions: suggestions ?? [],
      confidenceValidation: ConfidenceValidation(
        reportedConfidence: reportedConfidence,
        actualConfidence: actualConfidence,
        isAccurate: false,
        deviation: (reportedConfidence - actualConfidence).abs(),
      ),
      qualityFeedback: QualityAssessmentFeedback.inaccurate(reportedIssues),
    );
  }

  factory AnalysisFeedback.createMixed({
    required String analysisId,
    required AccuracyRating accuracyRating,
    required List<String> partialIssues,
    required List<FeedbackSuggestion> suggestions,
    required double reportedConfidence,
    required double actualConfidence,
    String? comments,
  }) {
    return AnalysisFeedback(
      analysisId: analysisId,
      timestamp: DateTime.now(),
      type: FeedbackType.mixed,
      satisfaction: UserSatisfaction.neutral,
      accuracyRating: accuracyRating,
      userComments: comments,
      reportedIssues: partialIssues,
      suggestions: suggestions,
      confidenceValidation: ConfidenceValidation(
        reportedConfidence: reportedConfidence,
        actualConfidence: actualConfidence,
        isAccurate: (reportedConfidence - actualConfidence).abs() <= 0.2,
        deviation: (reportedConfidence - actualConfidence).abs(),
      ),
      qualityFeedback: QualityAssessmentFeedback.partiallyAccurate(partialIssues),
    );
  }

  static UserSatisfaction _getSatisfactionFromAccuracy(AccuracyRating rating) {
    switch (rating) {
      case AccuracyRating.excellent:
      case AccuracyRating.veryGood:
        return UserSatisfaction.verySatisfied;
      case AccuracyRating.good:
        return UserSatisfaction.satisfied;
      case AccuracyRating.acceptable:
        return UserSatisfaction.neutral;
      case AccuracyRating.poor:
        return UserSatisfaction.dissatisfied;
      case AccuracyRating.veryPoor:
        return UserSatisfaction.veryDissatisfied;
    }
  }

  bool get isPositiveFeedback => type == FeedbackType.positive;
  bool get isNegativeFeedback => type == FeedbackType.negative;
  bool get hasIssues => reportedIssues.isNotEmpty;
  bool get hasSuggestions => suggestions.isNotEmpty;
  bool get isConfidenceAccurate => confidenceValidation.isAccurate;

  /// Vypočítá váhu tohoto feedbacku pro učení modelu
  double get learningWeight {
    double weight = 1.0;

    // Váha na základě typu feedbacku
    switch (type) {
      case FeedbackType.positive:
        weight *= 1.0;
        break;
      case FeedbackType.negative:
        weight *= 1.5; // Negativní feedback má vyšší váhu
        break;
      case FeedbackType.mixed:
        weight *= 1.2;
        break;
    }

    // Váha na základě přesnosti confidence score
    if (confidenceValidation.deviation <= 0.1) {
      weight *= 1.3; // Přesné confidence skóre má vyšší váhu
    } else if (confidenceValidation.deviation >= 0.3) {
      weight *= 0.8; // Nepřesné confidence skóre má nižší váhu
    }

    // Váha na základě kvality komentářů
    if (userComments != null && userComments!.length > 20) {
      weight *= 1.1; // Detailní komentáře mají vyšší váhu
    }

    return weight;
  }

  /// Identifikuje oblasti pro zlepšení na základě feedbacku
  List<ImprovementArea> getImprovementAreas() {
    final areas = <ImprovementArea>[];

    // Analýza accuracy ratingu
    if (accuracyRating == AccuracyRating.poor || 
        accuracyRating == AccuracyRating.veryPoor) {
      areas.add(ImprovementArea.modelAccuracy);
    }

    // Analýza confidence validace
    if (!confidenceValidation.isAccurate) {
      areas.add(ImprovementArea.confidenceCalibration);
    }

    // Analýza quality feedback
    if (!qualityFeedback.wasAccurate) {
      areas.add(ImprovementArea.imageQualityAssessment);
    }

    // Analýza reportovaných problémů
    for (final issue in reportedIssues) {
      if (issue.toLowerCase().contains('blur') || 
          issue.toLowerCase().contains('rozmazané')) {
        areas.add(ImprovementArea.blurDetection);
      }
      if (issue.toLowerCase().contains('light') || 
          issue.toLowerCase().contains('osvětlení')) {
        areas.add(ImprovementArea.lightingAssessment);
      }
      if (issue.toLowerCase().contains('missing') || 
          issue.toLowerCase().contains('chybí')) {
        areas.add(ImprovementArea.defectDetection);
      }
    }

    return areas.toSet().toList(); // Odstraní duplikáty
  }

  factory AnalysisFeedback.fromJson(Map<String, dynamic> json) {
    return AnalysisFeedback(
      analysisId: json['analysisId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: FeedbackType.values.firstWhere((e) => e.name == json['type']),
      satisfaction: UserSatisfaction.values.firstWhere((e) => e.name == json['satisfaction']),
      accuracyRating: AccuracyRating.values.firstWhere((e) => e.name == json['accuracyRating']),
      userComments: json['userComments'] as String?,
      reportedIssues: (json['reportedIssues'] as List<dynamic>).cast<String>(),
      suggestions: (json['suggestions'] as List<dynamic>)
          .map((e) => FeedbackSuggestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      confidenceValidation: ConfidenceValidation.fromJson(json['confidenceValidation'] as Map<String, dynamic>),
      qualityFeedback: QualityAssessmentFeedback.fromJson(json['qualityFeedback'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'analysisId': analysisId,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'satisfaction': satisfaction.name,
      'accuracyRating': accuracyRating.name,
      'userComments': userComments,
      'reportedIssues': reportedIssues,
      'suggestions': suggestions.map((e) => e.toJson()).toList(),
      'confidenceValidation': confidenceValidation.toJson(),
      'qualityFeedback': qualityFeedback.toJson(),
    };
  }

  @override
  String toString() => 'AnalysisFeedback('
      'type: ${type.name}, '
      'satisfaction: ${satisfaction.name}, '
      'accuracy: ${accuracyRating.name})';
}

enum FeedbackType {
  positive,  // Analýza byla přesná a užitečná
  negative,  // Analýza byla nepřesná nebo neužitečná
  mixed      // Analýza byla částečně přesná
}

enum UserSatisfaction {
  veryDissatisfied,  // 1/5
  dissatisfied,      // 2/5
  neutral,           // 3/5
  satisfied,         // 4/5
  verySatisfied      // 5/5
}

enum AccuracyRating {
  veryPoor,    // 0-20% přesnost
  poor,        // 21-40% přesnost
  acceptable,  // 41-60% přesnost
  good,        // 61-80% přesnost
  veryGood,    // 81-95% přesnost
  excellent    // 96-100% přesnost
}

enum ImprovementArea {
  modelAccuracy,              // Celková přesnost modelu
  confidenceCalibration,      // Kalibrace confidence score
  imageQualityAssessment,     // Hodnocení kvality snímků
  blurDetection,             // Detekce rozmazání
  lightingAssessment,        // Hodnocení osvětlení
  defectDetection,           // Detekce vad
  userInterface,             // Uživatelské rozhraní
  responseTime               // Rychlost odpovědi
}

class FeedbackSuggestion {
  final SuggestionType type;
  final String title;
  final String description;
  final SuggestionPriority priority;
  final List<String> tags;

  const FeedbackSuggestion({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.tags,
  });

  factory FeedbackSuggestion.imageQuality(String description) => FeedbackSuggestion(
    type: SuggestionType.imageQuality,
    title: 'Zlepšení kvality snímku',
    description: description,
    priority: SuggestionPriority.high,
    tags: ['quality', 'image'],
  );

  factory FeedbackSuggestion.userInterface(String description) => FeedbackSuggestion(
    type: SuggestionType.userInterface,
    title: 'Vylepšení uživatelského rozhraní',
    description: description,
    priority: SuggestionPriority.medium,
    tags: ['ui', 'ux'],
  );

  factory FeedbackSuggestion.feature(String title, String description) => FeedbackSuggestion(
    type: SuggestionType.newFeature,
    title: title,
    description: description,
    priority: SuggestionPriority.low,
    tags: ['feature'],
  );

  factory FeedbackSuggestion.fromJson(Map<String, dynamic> json) {
    return FeedbackSuggestion(
      type: SuggestionType.values.firstWhere((e) => e.name == json['type']),
      title: json['title'] as String,
      description: json['description'] as String,
      priority: SuggestionPriority.values.firstWhere((e) => e.name == json['priority']),
      tags: (json['tags'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'title': title,
      'description': description,
      'priority': priority.name,
      'tags': tags,
    };
  }
}

enum SuggestionType {
  imageQuality,     // Návrhy pro zlepšení kvality snímků
  userInterface,    // Návrhy pro UI/UX
  newFeature,       // Návrhy nových funkcí
  performance,      // Návrhy pro výkon
  accuracy          // Návrhy pro přesnost
}

enum SuggestionPriority {
  low,      // Nízká priorita
  medium,   // Střední priorita
  high,     // Vysoká priorita
  critical  // Kritická priorita
}

class ConfidenceValidation {
  final double reportedConfidence;  // Co systém nahlásil
  final double actualConfidence;    // Co uživatel hodnotí jako skutečné
  final bool isAccurate;           // Je reported confidence přesný?
  final double deviation;          // Velikost odchylky

  const ConfidenceValidation({
    required this.reportedConfidence,
    required this.actualConfidence,
    required this.isAccurate,
    required this.deviation,
  });

  ConfidenceCalibration get calibrationCategory {
    if (deviation <= 0.1) return ConfidenceCalibration.wellCalibrated;
    if (deviation <= 0.2) return ConfidenceCalibration.moderatelyCalibrated;
    if (reportedConfidence > actualConfidence) return ConfidenceCalibration.overconfident;
    return ConfidenceCalibration.underconfident;
  }

  factory ConfidenceValidation.fromJson(Map<String, dynamic> json) {
    return ConfidenceValidation(
      reportedConfidence: (json['reportedConfidence'] as num).toDouble(),
      actualConfidence: (json['actualConfidence'] as num).toDouble(),
      isAccurate: json['isAccurate'] as bool,
      deviation: (json['deviation'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reportedConfidence': reportedConfidence,
      'actualConfidence': actualConfidence,
      'isAccurate': isAccurate,
      'deviation': deviation,
    };
  }
}

enum ConfidenceCalibration {
  wellCalibrated,        // Dobře kalibrováno (±10%)
  moderatelyCalibrated,  // Středně kalibrováno (±20%)
  overconfident,         // Systém je příliš sebevědomý
  underconfident         // Systém je málo sebevědomý
}

class QualityAssessmentFeedback {
  final bool wasAccurate;              // Bylo hodnocení kvality přesné?
  final List<String> missedIssues;     // Problémy, které systém nedetekoval
  final List<String> falsePositives;   // Problémy, které systém špatně detekoval
  final QualityFeedbackType type;

  const QualityAssessmentFeedback({
    required this.wasAccurate,
    required this.missedIssues,
    required this.falsePositives,
    required this.type,
  });

  factory QualityAssessmentFeedback.accurate() => const QualityAssessmentFeedback(
    wasAccurate: true,
    missedIssues: [],
    falsePositives: [],
    type: QualityFeedbackType.accurate,
  );

  factory QualityAssessmentFeedback.inaccurate(List<String> issues) => QualityAssessmentFeedback(
    wasAccurate: false,
    missedIssues: issues,
    falsePositives: [],
    type: QualityFeedbackType.inaccurate,
  );

  factory QualityAssessmentFeedback.partiallyAccurate(List<String> issues) => QualityAssessmentFeedback(
    wasAccurate: false,
    missedIssues: issues,
    falsePositives: [],
    type: QualityFeedbackType.partiallyAccurate,
  );

  bool get hasIssues => missedIssues.isNotEmpty || falsePositives.isNotEmpty;
  int get totalIssues => missedIssues.length + falsePositives.length;

  factory QualityAssessmentFeedback.fromJson(Map<String, dynamic> json) {
    return QualityAssessmentFeedback(
      wasAccurate: json['wasAccurate'] as bool,
      missedIssues: (json['missedIssues'] as List<dynamic>).cast<String>(),
      falsePositives: (json['falsePositives'] as List<dynamic>).cast<String>(),
      type: QualityFeedbackType.values.firstWhere((e) => e.name == json['type']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wasAccurate': wasAccurate,
      'missedIssues': missedIssues,
      'falsePositives': falsePositives,
      'type': type.name,
    };
  }
}

enum QualityFeedbackType {
  accurate,            // Hodnocení bylo přesné
  inaccurate,         // Hodnocení bylo nepřesné
  partiallyAccurate   // Hodnocení bylo částečně přesné
}

enum ImprovementCategory {
  imageQuality,       // Kvalita snímků
  analysisConfidence, // Jistota analýzy
  modelPerformance,   // Výkonnost modelu
  userExperience,     // Uživatelská zkušenost
  performance        // Výkon systému
}