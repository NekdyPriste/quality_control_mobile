// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quality_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QualityReport _$QualityReportFromJson(Map<String, dynamic> json) =>
    QualityReport(
      id: (json['id'] as num).toInt(),
      referenceImagePath: json['referenceImagePath'] as String,
      partImagePath: json['partImagePath'] as String,
      partType: $enumDecode(_$PartTypeEnumMap, json['partType']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      comparisonResult: ComparisonResult.fromJson(
          json['comparisonResult'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$QualityReportToJson(QualityReport instance) =>
    <String, dynamic>{
      'id': instance.id,
      'referenceImagePath': instance.referenceImagePath,
      'partImagePath': instance.partImagePath,
      'partType': _$PartTypeEnumMap[instance.partType]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'comparisonResult': instance.comparisonResult,
    };

const _$PartTypeEnumMap = {
  PartType.vylisky: 'VÝLISKY',
  PartType.obrabene: 'OBRÁBĚNÉ',
};
