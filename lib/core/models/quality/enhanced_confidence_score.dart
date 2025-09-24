import 'image_quality_metrics.dart';

class EnhancedConfidenceScore {
  final double imageQualityScore;    // 0.0-1.0 z ImageQualityMetrics
  final double modelReliabilityScore; // 0.0-1.0 spolehlivost AI modelu
  final double contextualScore;      // 0.0-1.0 kontextuální faktory
  final double historicalScore;      // 0.0-1.0 na základě historie úspěšnosti
  final double complexityPenalty;    // 0.0-1.0 penalizace za složitost úkolu
  final double overallConfidence;    // 0.0-1.0 celková jistota
  final List<ConfidenceFactor> factors; // Detailní faktory ovlivňující jistotu

  const EnhancedConfidenceScore({
    required this.imageQualityScore,
    required this.modelReliabilityScore,
    required this.contextualScore,
    required this.historicalScore,
    required this.complexityPenalty,
    required this.overallConfidence,
    required this.factors,
  });

  factory EnhancedConfidenceScore.calculate({
    required ImageQualityMetrics referenceQuality,
    required ImageQualityMetrics partQuality,
    required AnalysisComplexity complexity,
    required ModelPerformanceHistory? history,
    required Map<String, dynamic> contextualData,
  }) {
    final factors = <ConfidenceFactor>[];
    
    // 1. Image Quality Score (30% váha)
    final avgImageQuality = (referenceQuality.overallScore + partQuality.overallScore) / 2;
    final imageQualityScore = avgImageQuality;
    factors.add(ConfidenceFactor(
      type: ConfidenceFactorType.imageQuality,
      impact: FactorImpact.high,
      score: imageQualityScore,
      description: _getImageQualityDescription(imageQualityScore),
    ));

    // 2. Model Reliability Score (25% váha)
    final modelReliabilityScore = _calculateModelReliability(complexity);
    factors.add(ConfidenceFactor(
      type: ConfidenceFactorType.modelReliability,
      impact: FactorImpact.high,
      score: modelReliabilityScore,
      description: _getModelReliabilityDescription(complexity),
    ));

    // 3. Contextual Score (20% váha)
    final contextualScore = _calculateContextualScore(contextualData);
    factors.add(ConfidenceFactor(
      type: ConfidenceFactorType.contextual,
      impact: FactorImpact.medium,
      score: contextualScore,
      description: _getContextualDescription(contextualData),
    ));

    // 4. Historical Score (15% váha)
    final historicalScore = _calculateHistoricalScore(history);
    factors.add(ConfidenceFactor(
      type: ConfidenceFactorType.historical,
      impact: FactorImpact.medium,
      score: historicalScore,
      description: _getHistoricalDescription(history),
    ));

    // 5. Complexity Penalty (10% váha)
    final complexityPenalty = _calculateComplexityPenalty(complexity);
    factors.add(ConfidenceFactor(
      type: ConfidenceFactorType.complexity,
      impact: FactorImpact.low,
      score: 1.0 - complexityPenalty,
      description: _getComplexityDescription(complexity),
    ));

    // Váhovaný výpočet celkové jistoty
    final overallConfidence = _calculateWeightedConfidence({
      'imageQuality': imageQualityScore * 0.30,
      'modelReliability': modelReliabilityScore * 0.25,
      'contextual': contextualScore * 0.20,
      'historical': historicalScore * 0.15,
      'complexity': (1.0 - complexityPenalty) * 0.10,
    });

    return EnhancedConfidenceScore(
      imageQualityScore: imageQualityScore,
      modelReliabilityScore: modelReliabilityScore,
      contextualScore: contextualScore,
      historicalScore: historicalScore,
      complexityPenalty: complexityPenalty,
      overallConfidence: overallConfidence,
      factors: factors,
    );
  }

  static double _calculateModelReliability(AnalysisComplexity complexity) {
    switch (complexity) {
      case AnalysisComplexity.simple:
        return 0.95; // Jednoduchá analýza - vysoká spolehlivost
      case AnalysisComplexity.moderate:
        return 0.85; // Střední složitost
      case AnalysisComplexity.complex:
        return 0.75; // Složitá analýza - nižší spolehlivost
      case AnalysisComplexity.extreme:
        return 0.60; // Extrémně složitá - značné nejistoty
    }
  }

  static double _calculateContextualScore(Map<String, dynamic> data) {
    double score = 0.7; // Základní skóre

    // Faktory zlepšující kontextuální skóre
    if (data['hasReferenceModel'] == true) score += 0.15;
    if (data['goodLightingConditions'] == true) score += 0.10;
    if (data['stableEnvironment'] == true) score += 0.05;
    
    // Faktory zhoršující kontextuální skóre
    if (data['hasReflectiveSurfaces'] == true) score -= 0.10;
    if (data['poorAngle'] == true) score -= 0.15;
    if (data['backgroundNoise'] == true) score -= 0.05;

    return score.clamp(0.0, 1.0);
  }

  static double _calculateHistoricalScore(ModelPerformanceHistory? history) {
    if (history == null) return 0.7; // Neutrální hodnota bez historie
    
    final successRate = history.successfulAnalyses / history.totalAnalyses;
    final recentAccuracy = history.recentAccuracy;
    
    // Kombinace dlouhodobé úspěšnosti a nedávné přesnosti
    return (successRate * 0.4 + recentAccuracy * 0.6).clamp(0.0, 1.0);
  }

  static double _calculateComplexityPenalty(AnalysisComplexity complexity) {
    switch (complexity) {
      case AnalysisComplexity.simple:
        return 0.05; // Minimální penalizace
      case AnalysisComplexity.moderate:
        return 0.15;
      case AnalysisComplexity.complex:
        return 0.25;
      case AnalysisComplexity.extreme:
        return 0.40; // Vysoká penalizace za složitost
    }
  }

  static double _calculateWeightedConfidence(Map<String, double> scores) {
    return scores.values.reduce((a, b) => a + b).clamp(0.0, 1.0);
  }

  static String _getImageQualityDescription(double score) {
    if (score >= 0.8) return 'Vynikající kvalita snímků';
    if (score >= 0.6) return 'Dobrá kvalita snímků';
    if (score >= 0.4) return 'Přijatelná kvalita snímků';
    return 'Nízká kvalita snímků';
  }

  static String _getModelReliabilityDescription(AnalysisComplexity complexity) {
    switch (complexity) {
      case AnalysisComplexity.simple:
        return 'AI model velmi spolehlivý pro tento typ analýzy';
      case AnalysisComplexity.moderate:
        return 'AI model spolehlivý s občasnými nejistotami';
      case AnalysisComplexity.complex:
        return 'AI model středně spolehlivý pro složitou analýzu';
      case AnalysisComplexity.extreme:
        return 'AI model méně spolehlivý pro extrémně složitou analýzu';
    }
  }

  static String _getContextualDescription(Map<String, dynamic> data) {
    final positiveFactors = <String>[];
    final negativeFactors = <String>[];

    if (data['hasReferenceModel'] == true) positiveFactors.add('referenční model');
    if (data['goodLightingConditions'] == true) positiveFactors.add('dobré osvětlení');
    if (data['hasReflectiveSurfaces'] == true) negativeFactors.add('reflexní povrchy');
    if (data['poorAngle'] == true) negativeFactors.add('nevhodný úhel');

    if (positiveFactors.isEmpty && negativeFactors.isEmpty) {
      return 'Standardní podmínky analýzy';
    }

    final parts = <String>[];
    if (positiveFactors.isNotEmpty) {
      parts.add('Pozitivní: ${positiveFactors.join(', ')}');
    }
    if (negativeFactors.isNotEmpty) {
      parts.add('Negativní: ${negativeFactors.join(', ')}');
    }
    
    return parts.join('; ');
  }

  static String _getHistoricalDescription(ModelPerformanceHistory? history) {
    if (history == null) return 'Žádná historická data dostupná';
    
    final successRate = (history.successfulAnalyses / history.totalAnalyses * 100).round();
    return 'Úspěšnost modelu: $successRate% z ${history.totalAnalyses} analýz';
  }

  static String _getComplexityDescription(AnalysisComplexity complexity) {
    switch (complexity) {
      case AnalysisComplexity.simple:
        return 'Jednoduchá analýza - minimální riziko chyby';
      case AnalysisComplexity.moderate:
        return 'Středně složitá analýza';
      case AnalysisComplexity.complex:
        return 'Složitá analýza - zvýšené riziko nejistoty';
      case AnalysisComplexity.extreme:
        return 'Extrémně složitá analýza - vysoké riziko chyby';
    }
  }

  ConfidenceLevel get confidenceLevel {
    if (overallConfidence >= 0.9) return ConfidenceLevel.veryHigh;
    if (overallConfidence >= 0.7) return ConfidenceLevel.high;
    if (overallConfidence >= 0.5) return ConfidenceLevel.medium;
    if (overallConfidence >= 0.3) return ConfidenceLevel.low;
    return ConfidenceLevel.veryLow;
  }

  bool get isReliableForDecisionMaking => overallConfidence >= 0.7;
  bool get requiresHumanReview => overallConfidence < 0.5;
  bool get shouldShowWarnings => overallConfidence < 0.7;

  factory EnhancedConfidenceScore.fromJson(Map<String, dynamic> json) {
    return EnhancedConfidenceScore(
      imageQualityScore: (json['imageQualityScore'] as num).toDouble(),
      modelReliabilityScore: (json['modelReliabilityScore'] as num).toDouble(),
      contextualScore: (json['contextualScore'] as num).toDouble(),
      historicalScore: (json['historicalScore'] as num).toDouble(),
      complexityPenalty: (json['complexityPenalty'] as num).toDouble(),
      overallConfidence: (json['overallConfidence'] as num).toDouble(),
      factors: (json['factors'] as List<dynamic>)
          .map((e) => ConfidenceFactor.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageQualityScore': imageQualityScore,
      'modelReliabilityScore': modelReliabilityScore,
      'contextualScore': contextualScore,
      'historicalScore': historicalScore,
      'complexityPenalty': complexityPenalty,
      'overallConfidence': overallConfidence,
      'factors': factors.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() => 'EnhancedConfidenceScore('
      'overall: ${overallConfidence.toStringAsFixed(2)}, '
      'level: ${confidenceLevel.name})';
}

enum AnalysisComplexity {
  simple,    // Jednoduchá geometrie, jasné rozdíly
  moderate,  // Střední složitost, některé nejasnosti
  complex,   // Složitá geometrie, jemné rozdíly
  extreme    // Extrémně složité případy
}

enum ConfidenceLevel {
  veryHigh, // 0.9-1.0 - Velmi vysoká jistota
  high,     // 0.7-0.89 - Vysoká jistota
  medium,   // 0.5-0.69 - Střední jistota
  low,      // 0.3-0.49 - Nízká jistota
  veryLow   // 0.0-0.29 - Velmi nízká jistota
}

class ConfidenceFactor {
  final ConfidenceFactorType type;
  final FactorImpact impact;
  final double score;
  final String description;

  const ConfidenceFactor({
    required this.type,
    required this.impact,
    required this.score,
    required this.description,
  });

  factory ConfidenceFactor.fromJson(Map<String, dynamic> json) {
    return ConfidenceFactor(
      type: ConfidenceFactorType.values.firstWhere((e) => e.name == json['type']),
      impact: FactorImpact.values.firstWhere((e) => e.name == json['impact']),
      score: (json['score'] as num).toDouble(),
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'impact': impact.name,
      'score': score,
      'description': description,
    };
  }
}

enum ConfidenceFactorType {
  imageQuality,
  modelReliability,
  contextual,
  historical,
  complexity
}

enum FactorImpact { low, medium, high }

class ModelPerformanceHistory {
  final int totalAnalyses;
  final int successfulAnalyses;
  final double recentAccuracy;
  final DateTime lastUpdated;

  const ModelPerformanceHistory({
    required this.totalAnalyses,
    required this.successfulAnalyses,
    required this.recentAccuracy,
    required this.lastUpdated,
  });

  factory ModelPerformanceHistory.fromJson(Map<String, dynamic> json) {
    return ModelPerformanceHistory(
      totalAnalyses: json['totalAnalyses'] as int,
      successfulAnalyses: json['successfulAnalyses'] as int,
      recentAccuracy: (json['recentAccuracy'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalAnalyses': totalAnalyses,
      'successfulAnalyses': successfulAnalyses,
      'recentAccuracy': recentAccuracy,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}