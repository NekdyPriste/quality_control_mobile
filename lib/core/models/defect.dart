enum DefectType {
  missing,
  extra,
  deformed,
  dimensional,
}

enum DefectSeverity {
  critical,
  major,
  minor,
}

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

  factory DefectLocation.fromJson(Map<String, dynamic> json) {
    return DefectLocation(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }
}

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

  factory Defect.fromJson(Map<String, dynamic> json) {
    return Defect(
      type: DefectType.values.firstWhere((e) => e.name.toUpperCase() == json['type'] || e.name == json['type']),
      description: json['description'] as String,
      severity: DefectSeverity.values.firstWhere((e) => e.name.toUpperCase() == json['severity'] || e.name == json['severity']),
      location: DefectLocation.fromJson(json['location'] as Map<String, dynamic>),
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name.toUpperCase(),
      'description': description,
      'severity': severity.name.toUpperCase(),
      'location': location.toJson(),
      'confidence': confidence,
    };
  }
}