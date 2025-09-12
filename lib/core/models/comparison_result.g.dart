// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comparison_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ComparisonResult _$ComparisonResultFromJson(Map<String, dynamic> json) =>
    ComparisonResult(
      overallQuality:
          $enumDecode(_$QualityStatusEnumMap, json['overall_quality']),
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      defectsFound: (json['defects_found'] as List<dynamic>)
          .map((e) => Defect.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] as String,
    );

Map<String, dynamic> _$ComparisonResultToJson(ComparisonResult instance) =>
    <String, dynamic>{
      'overall_quality': _$QualityStatusEnumMap[instance.overallQuality]!,
      'confidence_score': instance.confidenceScore,
      'defects_found': instance.defectsFound,
      'summary': instance.summary,
    };

const _$QualityStatusEnumMap = {
  QualityStatus.pass: 'PASS',
  QualityStatus.fail: 'FAIL',
  QualityStatus.warning: 'WARNING',
};
