// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_annotation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorAnnotation _$ErrorAnnotationFromJson(Map<String, dynamic> json) =>
    ErrorAnnotation(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      errorType: $enumDecode(_$ErrorTypeEnumMap, json['errorType']),
      severity: $enumDecode(_$ErrorSeverityEnumMap, json['severity']),
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ErrorAnnotationToJson(ErrorAnnotation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'x': instance.x,
      'y': instance.y,
      'errorType': _$ErrorTypeEnumMap[instance.errorType]!,
      'severity': _$ErrorSeverityEnumMap[instance.severity]!,
      'description': instance.description,
      'timestamp': instance.timestamp.toIso8601String(),
      'confidence': instance.confidence,
      'width': instance.width,
      'height': instance.height,
    };

const _$ErrorTypeEnumMap = {
  ErrorType.crack: 'crack',
  ErrorType.scratch: 'scratch',
  ErrorType.dent: 'dent',
  ErrorType.discoloration: 'discoloration',
  ErrorType.deformation: 'deformation',
  ErrorType.surfaceDefect: 'surfaceDefect',
  ErrorType.dimensionalError: 'dimensionalError',
  ErrorType.materialDefect: 'materialDefect',
  ErrorType.other: 'other',
};

const _$ErrorSeverityEnumMap = {
  ErrorSeverity.critical: 'critical',
  ErrorSeverity.major: 'major',
  ErrorSeverity.minor: 'minor',
  ErrorSeverity.cosmetic: 'cosmetic',
};

AnnotatedImage _$AnnotatedImageFromJson(Map<String, dynamic> json) =>
    AnnotatedImage(
      imagePath: json['imagePath'] as String,
      annotations: (json['annotations'] as List<dynamic>)
          .map((e) => ErrorAnnotation.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      partSerialNumber: json['partSerialNumber'] as String?,
      operatorId: json['operatorId'] as String?,
    );

Map<String, dynamic> _$AnnotatedImageToJson(AnnotatedImage instance) =>
    <String, dynamic>{
      'imagePath': instance.imagePath,
      'annotations': instance.annotations.map((e) => e.toJson()).toList(),
      'metadata': instance.metadata,
      'createdAt': instance.createdAt.toIso8601String(),
      'partSerialNumber': instance.partSerialNumber,
      'operatorId': instance.operatorId,
    };

K $enumDecode<K, V>(
  Map<K, V> enumValues,
  Object? source, {
  K? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue, enumValues.values.first);
    },
  ).key;
}