import 'comparison_result.dart';
import 'defect.dart';

enum PartType {
  vylisky,
  obrabene,
}

class QualityReport {
  final int? id;
  final String? referenceImagePath;
  final String? partImagePath;
  final PartType? partType;
  final DateTime? createdAt;
  final ComparisonResult? comparisonResult;
  
  // Enhanced system properties (optional for backward compatibility)
  final double? overallScore;
  final List<Defect>? defectsFound;
  final String? summary;
  final List<String>? recommendations;
  final String? confidenceLevel;
  final DateTime? analysisTimestamp;

  const QualityReport({
    this.id,
    this.referenceImagePath,
    this.partImagePath,
    this.partType,
    this.createdAt,
    this.comparisonResult,
    this.overallScore,
    this.defectsFound,
    this.summary,
    this.recommendations,
    this.confidenceLevel,
    this.analysisTimestamp,
  });

  // Legacy constructor for backward compatibility
  const QualityReport.legacy({
    required int this.id,
    required String this.referenceImagePath,
    required String this.partImagePath,
    required PartType this.partType,
    required DateTime this.createdAt,
    required ComparisonResult this.comparisonResult,
  }) : overallScore = null,
       defectsFound = null,
       summary = null,
       recommendations = null,
       confidenceLevel = null,
       analysisTimestamp = null;

  // Enhanced constructor for new system
  const QualityReport.enhanced({
    required double this.overallScore,
    required List<Defect> this.defectsFound,
    required String this.summary,
    required List<String> this.recommendations,
    required String this.confidenceLevel,
    required DateTime this.analysisTimestamp,
    this.id,
    this.referenceImagePath,
    this.partImagePath,
    this.partType,
    this.createdAt,
    this.comparisonResult,
  });

  factory QualityReport.fromJson(Map<String, dynamic> json) {
    return QualityReport(
      id: json['id'] as int?,
      referenceImagePath: json['referenceImagePath'] as String?,
      partImagePath: json['partImagePath'] as String?,
      partType: json['partType'] != null 
          ? PartType.values.firstWhere((e) => e.name == json['partType'] || e.name.toUpperCase() == json['partType'])
          : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      comparisonResult: json['comparisonResult'] != null 
          ? ComparisonResult.fromJson(json['comparisonResult'] as Map<String, dynamic>)
          : null,
      overallScore: json['overallScore'] != null ? (json['overallScore'] as num).toDouble() : null,
      defectsFound: json['defectsFound'] != null 
          ? (json['defectsFound'] as List<dynamic>)
              .map((e) => Defect.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      summary: json['summary'] as String?,
      recommendations: json['recommendations'] != null 
          ? (json['recommendations'] as List<dynamic>).cast<String>()
          : null,
      confidenceLevel: json['confidenceLevel'] as String?,
      analysisTimestamp: json['analysisTimestamp'] != null 
          ? DateTime.parse(json['analysisTimestamp'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'referenceImagePath': referenceImagePath,
      'partImagePath': partImagePath,
      'partType': partType?.name.toUpperCase(),
      'createdAt': createdAt?.toIso8601String(),
      'comparisonResult': comparisonResult?.toJson(),
      'overallScore': overallScore,
      'defectsFound': defectsFound?.map((e) => e.toJson()).toList(),
      'summary': summary,
      'recommendations': recommendations,
      'confidenceLevel': confidenceLevel,
      'analysisTimestamp': analysisTimestamp?.toIso8601String(),
    };
  }

  String get partTypeDisplayName {
    switch (partType) {
      case PartType.vylisky:
        return 'Výlisky';
      case PartType.obrabene:
        return 'Obráběné díly';
      case null:
        return 'Neznámý typ';
    }
  }

  bool get passed => comparisonResult?.overallQuality == QualityStatus.pass || (overallScore ?? 0.0) >= 0.8;
  
  String get statusDisplayName {
    if (comparisonResult != null) {
      switch (comparisonResult!.overallQuality) {
        case QualityStatus.pass:
          return 'Vyhovuje';
        case QualityStatus.fail:
          return 'Nevyhovuje';
        case QualityStatus.warning:
          return 'Upozornění';
      }
    }
    // Fallback based on overallScore
    final score = overallScore ?? 0.0;
    if (score >= 0.8) return 'Vyhovuje';
    if (score >= 0.5) return 'Upozornění';
    return 'Nevyhovuje';
  }
  
  bool get hasDefects => defectsFound?.isNotEmpty ?? comparisonResult?.hasDefects ?? false;
}