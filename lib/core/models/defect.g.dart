// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'defect.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DefectLocation _$DefectLocationFromJson(Map<String, dynamic> json) =>
    DefectLocation(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );

Map<String, dynamic> _$DefectLocationToJson(DefectLocation instance) =>
    <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
    };

Defect _$DefectFromJson(Map<String, dynamic> json) => Defect(
      type: $enumDecode(_$DefectTypeEnumMap, json['type']),
      description: json['description'] as String,
      severity: $enumDecode(_$DefectSeverityEnumMap, json['severity']),
      location:
          DefectLocation.fromJson(json['location'] as Map<String, dynamic>),
      confidence: (json['confidence'] as num).toDouble(),
    );

Map<String, dynamic> _$DefectToJson(Defect instance) => <String, dynamic>{
      'type': _$DefectTypeEnumMap[instance.type]!,
      'description': instance.description,
      'severity': _$DefectSeverityEnumMap[instance.severity]!,
      'location': instance.location,
      'confidence': instance.confidence,
    };

const _$DefectTypeEnumMap = {
  DefectType.missing: 'MISSING',
  DefectType.extra: 'EXTRA',
  DefectType.deformed: 'DEFORMED',
  DefectType.dimensional: 'DIMENSIONAL',
};

const _$DefectSeverityEnumMap = {
  DefectSeverity.critical: 'CRITICAL',
  DefectSeverity.major: 'MAJOR',
  DefectSeverity.minor: 'MINOR',
};
