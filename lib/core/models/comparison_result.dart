import 'defect.dart';

enum QualityStatus {
  pass,
  fail,
  warning,
}

class ComparisonResult {
  final QualityStatus overallQuality;
  final double confidenceScore;
  final List<Defect> defectsFound;
  
  final String summary;

  const ComparisonResult({
    required this.overallQuality,
    required this.confidenceScore,
    required this.defectsFound,
    required this.summary,
  });

  factory ComparisonResult.fromJson(Map<String, dynamic> json) {
    return ComparisonResult(
      overallQuality: QualityStatus.values.firstWhere((e) => e.name == json['overall_quality'] || e.name.toUpperCase() == json['overall_quality']),
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      defectsFound: (json['defects_found'] as List<dynamic>)
          .map((e) => Defect.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'overall_quality': overallQuality.name.toUpperCase(),
      'confidence_score': confidenceScore,
      'defects_found': defectsFound.map((e) => e.toJson()).toList(),
      'summary': summary,
    };
  }

  bool get hasDefects => defectsFound.isNotEmpty;
  
  int get criticalDefects => 
      defectsFound.where((d) => d.severity == DefectSeverity.critical).length;
      
  int get majorDefects => 
      defectsFound.where((d) => d.severity == DefectSeverity.major).length;
      
  int get minorDefects => 
      defectsFound.where((d) => d.severity == DefectSeverity.minor).length;
}