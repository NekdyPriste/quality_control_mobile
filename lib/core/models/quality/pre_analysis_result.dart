import 'image_quality_metrics.dart';

class PreAnalysisResult {
  final PreAnalysisDecision decision;
  final double expectedConfidence;
  final ImageQualityMetrics? referenceQuality;
  final ImageQualityMetrics? partQuality;
  final List<QualityIssue> issues;
  final List<String> recommendations;
  final String reason;
  final TokenSavingEstimate tokenSaving;

  const PreAnalysisResult({
    required this.decision,
    required this.expectedConfidence,
    this.referenceQuality,
    this.partQuality,
    this.issues = const [],
    this.recommendations = const [],
    required this.reason,
    required this.tokenSaving,
  });

  factory PreAnalysisResult.proceed({
    required double expectedConfidence,
    required ImageQualityMetrics referenceQuality,
    required ImageQualityMetrics partQuality,
    List<QualityIssue> issues = const [],
  }) {
    return PreAnalysisResult(
      decision: PreAnalysisDecision.proceed,
      expectedConfidence: expectedConfidence,
      referenceQuality: referenceQuality,
      partQuality: partQuality,
      issues: issues,
      reason: 'Kvalita snímků je dostatečná pro AI analýzu',
      tokenSaving: TokenSavingEstimate.none(),
    );
  }

  factory PreAnalysisResult.proceedWithWarning({
    required double expectedConfidence,
    required ImageQualityMetrics referenceQuality,
    required ImageQualityMetrics partQuality,
    required List<QualityIssue> issues,
    required List<String> recommendations,
  }) {
    return PreAnalysisResult(
      decision: PreAnalysisDecision.proceedWithWarning,
      expectedConfidence: expectedConfidence,
      referenceQuality: referenceQuality,
      partQuality: partQuality,
      issues: issues,
      recommendations: recommendations,
      reason: 'Kvalita snímků je přijatelná, ale s omezeními',
      tokenSaving: TokenSavingEstimate.none(),
    );
  }

  factory PreAnalysisResult.reject({
    required String reason,
    required List<String> recommendations,
    required ImageQualityMetrics? referenceQuality,
    required ImageQualityMetrics? partQuality,
    required List<QualityIssue> issues,
    required int savedTokens,
  }) {
    return PreAnalysisResult(
      decision: PreAnalysisDecision.rejectAndRetake,
      expectedConfidence: 0.0,
      referenceQuality: referenceQuality,
      partQuality: partQuality,
      issues: issues,
      recommendations: recommendations,
      reason: reason,
      tokenSaving: TokenSavingEstimate.significant(savedTokens),
    );
  }

  factory PreAnalysisResult.optimizeFirst({
    required double expectedConfidence,
    required ImageQualityMetrics referenceQuality,
    required ImageQualityMetrics partQuality,
    required List<QualityIssue> issues,
    required List<String> recommendations,
  }) {
    return PreAnalysisResult(
      decision: PreAnalysisDecision.optimizeFirst,
      expectedConfidence: expectedConfidence,
      referenceQuality: referenceQuality,
      partQuality: partQuality,
      issues: issues,
      recommendations: recommendations,
      reason: 'Snímky vyžadují optimalizaci před AI analýzou',
      tokenSaving: TokenSavingEstimate.minor(50),
    );
  }

  bool get shouldProceedToAI => 
      decision == PreAnalysisDecision.proceed || 
      decision == PreAnalysisDecision.proceedWithWarning;

  bool get hasWarnings => issues.isNotEmpty;

  bool get hasCriticalIssues => 
      issues.any((issue) => issue.severity == IssueSeverity.critical);

  AIModelRecommendation get recommendedModel {
    if (expectedConfidence >= 0.8) {
      return AIModelRecommendation.premium; // Použij nejlepší model
    } else if (expectedConfidence >= 0.6) {
      return AIModelRecommendation.standard; // Standardní model
    } else {
      return AIModelRecommendation.basic; // Levnější model pro nejisté případy
    }
  }

  factory PreAnalysisResult.fromJson(Map<String, dynamic> json) {
    return PreAnalysisResult(
      decision: PreAnalysisDecision.values.firstWhere((e) => e.name == json['decision']),
      expectedConfidence: (json['expectedConfidence'] as num).toDouble(),
      referenceQuality: json['referenceQuality'] != null 
          ? ImageQualityMetrics.fromJson(json['referenceQuality'] as Map<String, dynamic>) 
          : null,
      partQuality: json['partQuality'] != null 
          ? ImageQualityMetrics.fromJson(json['partQuality'] as Map<String, dynamic>) 
          : null,
      issues: (json['issues'] as List<dynamic>)
          .map((e) => QualityIssue.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendations: (json['recommendations'] as List<dynamic>).cast<String>(),
      reason: json['reason'] as String,
      tokenSaving: TokenSavingEstimate.fromJson(json['tokenSaving'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'decision': decision.name,
      'expectedConfidence': expectedConfidence,
      'referenceQuality': referenceQuality?.toJson(),
      'partQuality': partQuality?.toJson(),
      'issues': issues.map((e) => e.toJson()).toList(),
      'recommendations': recommendations,
      'reason': reason,
      'tokenSaving': tokenSaving.toJson(),
    };
  }

  @override
  String toString() => 'PreAnalysisResult(decision: ${decision.name}, '
      'confidence: ${expectedConfidence.toStringAsFixed(2)}, '
      'issues: ${issues.length})';
}

enum PreAnalysisDecision {
  proceed,              // ✅ Pokračuj do AI analýzy - vysoká kvalita
  proceedWithWarning,   // ⚠️ Pokračuj ale varuj uživatele - střední kvalita
  rejectAndRetake,      // ❌ NEpokračuj, požaduj nové snímky - UŠETŘI TOKENY
  optimizeFirst         // 🔧 Optimalizuj snímky pak pokračuj - částečné úspory
}

enum AIModelRecommendation {
  basic,     // Levnější model pro nejisté případy
  standard,  // Standardní model
  premium    // Nejlepší model pro kvalitní snímky
}

class TokenSavingEstimate {
  final int savedTokens;
  final double savedCostUSD;
  final TokenSavingLevel level;

  const TokenSavingEstimate({
    required this.savedTokens,
    required this.savedCostUSD,
    required this.level,
  });

  factory TokenSavingEstimate.none() => const TokenSavingEstimate(
    savedTokens: 0,
    savedCostUSD: 0.0,
    level: TokenSavingLevel.none,
  );

  factory TokenSavingEstimate.minor(int tokens) => TokenSavingEstimate(
    savedTokens: tokens,
    savedCostUSD: tokens * 0.00003, // Přibližná cena za token
    level: TokenSavingLevel.minor,
  );

  factory TokenSavingEstimate.significant(int tokens) => TokenSavingEstimate(
    savedTokens: tokens,
    savedCostUSD: tokens * 0.00003,
    level: TokenSavingLevel.significant,
  );

  factory TokenSavingEstimate.fromJson(Map<String, dynamic> json) {
    return TokenSavingEstimate(
      savedTokens: json['savedTokens'] as int,
      savedCostUSD: (json['savedCostUSD'] as num).toDouble(),
      level: TokenSavingLevel.values.firstWhere((e) => e.name == json['level']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'savedTokens': savedTokens,
      'savedCostUSD': savedCostUSD,
      'level': level.name,
    };
  }

  @override
  String toString() => savedTokens > 0 
      ? 'Saved $savedTokens tokens (\$${savedCostUSD.toStringAsFixed(4)})'
      : 'No tokens saved';
}

enum TokenSavingLevel {
  none,        // 0 tokenů ušetřeno
  minor,       // 1-100 tokenů ušetřeno  
  significant  // 100+ tokenů ušetřeno
}