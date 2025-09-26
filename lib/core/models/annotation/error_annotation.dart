import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'error_annotation.g.dart';

enum ErrorType {
  @JsonValue('crack')
  crack,

  @JsonValue('scratch')
  scratch,

  @JsonValue('dent')
  dent,

  @JsonValue('discoloration')
  discoloration,

  @JsonValue('deformation')
  deformation,

  @JsonValue('surface_defect')
  surfaceDefect,

  @JsonValue('dimensional_error')
  dimensionalError,

  @JsonValue('material_defect')
  materialDefect,

  @JsonValue('other')
  other,
}

enum ErrorSeverity {
  @JsonValue('critical')
  critical,

  @JsonValue('major')
  major,

  @JsonValue('minor')
  minor,

  @JsonValue('cosmetic')
  cosmetic,
}

@JsonSerializable()
class ErrorAnnotation {
  final String id;
  final double x; // X coordinate (0-1, relative to image width)
  final double y; // Y coordinate (0-1, relative to image height)
  final ErrorType errorType;
  final ErrorSeverity severity;
  final String description;
  final DateTime timestamp;
  final double confidence; // User confidence 0.0-1.0
  final double? width; // Optional bounding box width (0-1)
  final double? height; // Optional bounding box height (0-1)

  const ErrorAnnotation({
    required this.id,
    required this.x,
    required this.y,
    required this.errorType,
    required this.severity,
    required this.description,
    required this.timestamp,
    this.confidence = 1.0,
    this.width,
    this.height,
  });

  factory ErrorAnnotation.fromJson(Map<String, dynamic> json) =>
      _$ErrorAnnotationFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorAnnotationToJson(this);

  // Convert relative coordinates to absolute pixels
  Offset toPixelPosition(Size imageSize) {
    return Offset(x * imageSize.width, y * imageSize.height);
  }

  // Convert absolute pixels to relative coordinates
  static ErrorAnnotation fromPixelPosition({
    required String id,
    required Offset position,
    required Size imageSize,
    required ErrorType errorType,
    required ErrorSeverity severity,
    required String description,
    double confidence = 1.0,
    Size? boundingBoxSize,
  }) {
    return ErrorAnnotation(
      id: id,
      x: position.dx / imageSize.width,
      y: position.dy / imageSize.height,
      errorType: errorType,
      severity: severity,
      description: description,
      timestamp: DateTime.now(),
      confidence: confidence,
      width: boundingBoxSize != null ? boundingBoxSize.width / imageSize.width : null,
      height: boundingBoxSize != null ? boundingBoxSize.height / imageSize.height : null,
    );
  }

  Color get markerColor {
    switch (severity) {
      case ErrorSeverity.critical:
        return Colors.red;
      case ErrorSeverity.major:
        return Colors.orange;
      case ErrorSeverity.minor:
        return Colors.yellow;
      case ErrorSeverity.cosmetic:
        return Colors.blue;
    }
  }

  String get errorTypeDisplayName {
    switch (errorType) {
      case ErrorType.crack:
        return 'Prasklina';
      case ErrorType.scratch:
        return 'Škrábanec';
      case ErrorType.dent:
        return 'Promáčklina';
      case ErrorType.discoloration:
        return 'Změna barvy';
      case ErrorType.deformation:
        return 'Deformace';
      case ErrorType.surfaceDefect:
        return 'Vada povrchu';
      case ErrorType.dimensionalError:
        return 'Rozměrová chyba';
      case ErrorType.materialDefect:
        return 'Vada materiálu';
      case ErrorType.other:
        return 'Ostatní';
    }
  }

  String get severityDisplayName {
    switch (severity) {
      case ErrorSeverity.critical:
        return 'Kritická';
      case ErrorSeverity.major:
        return 'Velká';
      case ErrorSeverity.minor:
        return 'Malá';
      case ErrorSeverity.cosmetic:
        return 'Kosmetická';
    }
  }
}

@JsonSerializable()
class AnnotatedImage {
  final String imagePath;
  final List<ErrorAnnotation> annotations;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String? partSerialNumber;
  final String? operatorId;

  const AnnotatedImage({
    required this.imagePath,
    required this.annotations,
    required this.metadata,
    required this.createdAt,
    this.partSerialNumber,
    this.operatorId,
  });

  factory AnnotatedImage.fromJson(Map<String, dynamic> json) =>
      _$AnnotatedImageFromJson(json);

  Map<String, dynamic> toJson() => _$AnnotatedImageToJson(this);

  // Get statistics
  int get totalErrors => annotations.length;
  int get criticalErrors => annotations.where((a) => a.severity == ErrorSeverity.critical).length;
  int get majorErrors => annotations.where((a) => a.severity == ErrorSeverity.major).length;
  int get minorErrors => annotations.where((a) => a.severity == ErrorSeverity.minor).length;

  Map<ErrorType, int> get errorTypeCounts {
    final counts = <ErrorType, int>{};
    for (final annotation in annotations) {
      counts[annotation.errorType] = (counts[annotation.errorType] ?? 0) + 1;
    }
    return counts;
  }

  // Export for ML dataset (COCO format inspired)
  Map<String, dynamic> toMLDatasetFormat() {
    return {
      'image': {
        'path': imagePath,
        'width': metadata['width'] ?? 0,
        'height': metadata['height'] ?? 0,
        'created_at': createdAt.toIso8601String(),
      },
      'annotations': annotations.map((a) => {
        'id': a.id,
        'category': a.errorType.toString().split('.').last,
        'severity': a.severity.toString().split('.').last,
        'bbox': [
          a.x * (metadata['width'] ?? 0),
          a.y * (metadata['height'] ?? 0),
          a.width != null ? a.width! * (metadata['width'] ?? 0) : 10.0,
          a.height != null ? a.height! * (metadata['height'] ?? 0) : 10.0,
        ],
        'description': a.description,
        'confidence': a.confidence,
        'timestamp': a.timestamp.toIso8601String(),
      }).toList(),
      'metadata': {
        ...metadata,
        'part_serial': partSerialNumber,
        'operator': operatorId,
        'total_errors': totalErrors,
        'critical_errors': criticalErrors,
        'major_errors': majorErrors,
        'minor_errors': minorErrors,
      },
    };
  }
}