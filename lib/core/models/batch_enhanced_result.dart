import 'quality/enhanced_analysis_record.dart';
import 'comparison_result.dart';
import 'quality_report.dart';

/// Result jednotlivého enhanced analysis v batch operaci
class BatchEnhancedResult {
  final String pairId;
  final String referenceImagePath;
  final String partImagePath;
  final PartType partType;
  final String? partSerial;

  /// Enhanced Analysis výsledky
  final EnhancedAnalysisRecord? enhancedRecord;
  final ComparisonResult? basicResult;

  /// Performance metrics
  final DateTime processedAt;
  final Duration processingTime;
  final int? tokensUsed;
  final double? estimatedCost;

  /// Status informace
  final BatchEnhancedStatus status;
  final String? errorMessage;

  const BatchEnhancedResult({
    required this.pairId,
    required this.referenceImagePath,
    required this.partImagePath,
    required this.partType,
    this.partSerial,
    this.enhancedRecord,
    this.basicResult,
    required this.processedAt,
    required this.processingTime,
    this.tokensUsed,
    this.estimatedCost,
    required this.status,
    this.errorMessage,
  });

  factory BatchEnhancedResult.pending({
    required String pairId,
    required String referenceImagePath,
    required String partImagePath,
    required PartType partType,
    String? partSerial,
  }) {
    return BatchEnhancedResult(
      pairId: pairId,
      referenceImagePath: referenceImagePath,
      partImagePath: partImagePath,
      partType: partType,
      partSerial: partSerial,
      processedAt: DateTime.now(),
      processingTime: Duration.zero,
      status: BatchEnhancedStatus.pending,
    );
  }

  factory BatchEnhancedResult.completed({
    required String pairId,
    required String referenceImagePath,
    required String partImagePath,
    required PartType partType,
    String? partSerial,
    EnhancedAnalysisRecord? enhancedRecord,
    required ComparisonResult basicResult,
    required Duration processingTime,
    int? tokensUsed,
    double? estimatedCost,
  }) {
    return BatchEnhancedResult(
      pairId: pairId,
      referenceImagePath: referenceImagePath,
      partImagePath: partImagePath,
      partType: partType,
      partSerial: partSerial,
      enhancedRecord: enhancedRecord,
      basicResult: basicResult,
      processedAt: DateTime.now(),
      processingTime: processingTime,
      tokensUsed: tokensUsed,
      estimatedCost: estimatedCost,
      status: BatchEnhancedStatus.completed,
    );
  }

  factory BatchEnhancedResult.failed({
    required String pairId,
    required String referenceImagePath,
    required String partImagePath,
    required PartType partType,
    String? partSerial,
    required String errorMessage,
    required Duration processingTime,
  }) {
    return BatchEnhancedResult(
      pairId: pairId,
      referenceImagePath: referenceImagePath,
      partImagePath: partImagePath,
      partType: partType,
      partSerial: partSerial,
      processedAt: DateTime.now(),
      processingTime: processingTime,
      status: BatchEnhancedStatus.failed,
      errorMessage: errorMessage,
    );
  }

  // Getters pro analýzu výsledků
  bool get isCompleted => status == BatchEnhancedStatus.completed;
  bool get isFailed => status == BatchEnhancedStatus.failed;
  bool get isPending => status == BatchEnhancedStatus.pending;
  bool get isProcessing => status == BatchEnhancedStatus.processing;

  QualityStatus? get overallQuality => basicResult?.overallQuality;
  double? get confidenceScore => enhancedRecord?.confidenceScore?.overallConfidence;

  /// Získá celkový quality score (0.0-1.0) kombinující basic a enhanced výsledky
  double get combinedQualityScore {
    double score = 0.0;
    int factors = 0;

    // Basic result confidence
    if (basicResult?.confidenceScore != null) {
      score += basicResult!.confidenceScore;
      factors++;
    }

    // Enhanced confidence score
    if (enhancedRecord?.confidenceScore?.overallConfidence != null) {
      score += enhancedRecord!.confidenceScore!.overallConfidence;
      factors++;
    }

    // Overall quality score from enhanced record
    if (enhancedRecord?.overallQualityScore != null) {
      score += enhancedRecord!.overallQualityScore;
      factors++;
    }

    return factors > 0 ? score / factors : 0.0;
  }

  /// Vrátí seznam všech doporučení z enhanced analysis
  List<String> get allRecommendations {
    final recommendations = <String>[];

    if (enhancedRecord?.recommendation != null) {
      recommendations.addAll(
        enhancedRecord!.recommendation!.steps.map((step) => step.action)
      );
    }

    return recommendations;
  }

  /// Vytvoří kopii s aktualizovanými hodnotami
  BatchEnhancedResult copyWith({
    BatchEnhancedStatus? status,
    EnhancedAnalysisRecord? enhancedRecord,
    ComparisonResult? basicResult,
    Duration? processingTime,
    int? tokensUsed,
    double? estimatedCost,
    String? errorMessage,
  }) {
    return BatchEnhancedResult(
      pairId: pairId,
      referenceImagePath: referenceImagePath,
      partImagePath: partImagePath,
      partType: partType,
      partSerial: partSerial,
      enhancedRecord: enhancedRecord ?? this.enhancedRecord,
      basicResult: basicResult ?? this.basicResult,
      processedAt: processedAt,
      processingTime: processingTime ?? this.processingTime,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  factory BatchEnhancedResult.fromJson(Map<String, dynamic> json) {
    return BatchEnhancedResult(
      pairId: json['pairId'] as String,
      referenceImagePath: json['referenceImagePath'] as String,
      partImagePath: json['partImagePath'] as String,
      partType: PartType.values.firstWhere((e) => e.name == json['partType']),
      partSerial: json['partSerial'] as String?,
      enhancedRecord: json['enhancedRecord'] != null
          ? EnhancedAnalysisRecord.fromJson(json['enhancedRecord'] as Map<String, dynamic>)
          : null,
      basicResult: json['basicResult'] != null
          ? ComparisonResult.fromJson(json['basicResult'] as Map<String, dynamic>)
          : null,
      processedAt: DateTime.parse(json['processedAt'] as String),
      processingTime: Duration(milliseconds: json['processingTimeMs'] as int),
      tokensUsed: json['tokensUsed'] as int?,
      estimatedCost: json['estimatedCost'] != null ? (json['estimatedCost'] as num).toDouble() : null,
      status: BatchEnhancedStatus.values.firstWhere((e) => e.name == json['status']),
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pairId': pairId,
      'referenceImagePath': referenceImagePath,
      'partImagePath': partImagePath,
      'partType': partType.name,
      'partSerial': partSerial,
      'enhancedRecord': enhancedRecord?.toJson(),
      'basicResult': basicResult?.toJson(),
      'processedAt': processedAt.toIso8601String(),
      'processingTimeMs': processingTime.inMilliseconds,
      'tokensUsed': tokensUsed,
      'estimatedCost': estimatedCost,
      'status': status.name,
      'errorMessage': errorMessage,
    };
  }

  @override
  String toString() => 'BatchEnhancedResult('
      'pairId: $pairId, '
      'status: ${status.name}, '
      'quality: ${overallQuality?.name ?? 'N/A'}, '
      'confidence: ${confidenceScore?.toStringAsFixed(2) ?? 'N/A'})';
}

enum BatchEnhancedStatus {
  pending,     // Čeká na zpracování
  processing,  // Právě se zpracovává
  completed,   // Úspěšně dokončeno
  failed       // Selhalo
}