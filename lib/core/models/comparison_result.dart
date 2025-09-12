import 'package:json_annotation/json_annotation.dart';
import 'defect.dart';

part 'comparison_result.g.dart';

enum QualityStatus {
  @JsonValue('PASS')
  pass,
  @JsonValue('FAIL')
  fail,
  @JsonValue('WARNING')
  warning,
}

@JsonSerializable()
class ComparisonResult {
  @JsonKey(name: 'overall_quality')
  final QualityStatus overallQuality;
  
  @JsonKey(name: 'confidence_score')
  final double confidenceScore;
  
  @JsonKey(name: 'defects_found')
  final List<Defect> defectsFound;
  
  final String summary;

  const ComparisonResult({
    required this.overallQuality,
    required this.confidenceScore,
    required this.defectsFound,
    required this.summary,
  });

  factory ComparisonResult.fromJson(Map<String, dynamic> json) =>
      _$ComparisonResultFromJson(json);

  Map<String, dynamic> toJson() => _$ComparisonResultToJson(this);

  bool get hasDefects => defectsFound.isNotEmpty;
  
  int get criticalDefects => 
      defectsFound.where((d) => d.severity == DefectSeverity.critical).length;
      
  int get majorDefects => 
      defectsFound.where((d) => d.severity == DefectSeverity.major).length;
      
  int get minorDefects => 
      defectsFound.where((d) => d.severity == DefectSeverity.minor).length;
}