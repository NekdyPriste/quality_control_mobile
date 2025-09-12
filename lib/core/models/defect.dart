import 'package:json_annotation/json_annotation.dart';

part 'defect.g.dart';

enum DefectType {
  @JsonValue('MISSING')
  missing,
  @JsonValue('EXTRA')  
  extra,
  @JsonValue('DEFORMED')
  deformed,
  @JsonValue('DIMENSIONAL')
  dimensional,
}

enum DefectSeverity {
  @JsonValue('CRITICAL')
  critical,
  @JsonValue('MAJOR')
  major,
  @JsonValue('MINOR')
  minor,
}

@JsonSerializable()
class DefectLocation {
  final double x;
  final double y; 
  final double width;
  final double height;

  const DefectLocation({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory DefectLocation.fromJson(Map<String, dynamic> json) =>
      _$DefectLocationFromJson(json);

  Map<String, dynamic> toJson() => _$DefectLocationToJson(this);
}

@JsonSerializable()
class Defect {
  final DefectType type;
  final String description;
  final DefectSeverity severity;
  final DefectLocation location;
  final double confidence;

  const Defect({
    required this.type,
    required this.description,
    required this.severity,
    required this.location,
    required this.confidence,
  });

  factory Defect.fromJson(Map<String, dynamic> json) => _$DefectFromJson(json);

  Map<String, dynamic> toJson() => _$DefectToJson(this);
}