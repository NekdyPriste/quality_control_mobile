
class ImageQualityMetrics {
  final double sharpness;        // 0.0-1.0 (blur detection via Laplacian variance)
  final double brightness;       // 0.0-1.0 (histogram analysis, optimal: 0.4-0.7)
  final double contrast;         // 0.0-1.0 (RMS contrast, optimal: 0.3-0.8)
  final double noiseLevel;       // 0.0-1.0 (higher = more noise = worse quality)
  final double resolution;       // 0.0-1.0 (relative to minimum requirements)
  final double compression;      // 0.0-1.0 (JPEG artifacts detection, higher = better)
  final double objectCoverage;   // 0.0-1.0 (% of frame covered by main object)
  final double edgeClarity;      // 0.0-1.0 (edge detection strength)
  final double overallScore;     // 0.0-1.0 (weighted average of all metrics)

  const ImageQualityMetrics({
    required this.sharpness,
    required this.brightness,
    required this.contrast,
    required this.noiseLevel,
    required this.resolution,
    required this.compression,
    required this.objectCoverage,
    required this.edgeClarity,
    required this.overallScore,
  });

  factory ImageQualityMetrics.fromJson(Map<String, dynamic> json) {
    return ImageQualityMetrics(
      sharpness: (json['sharpness'] as num).toDouble(),
      brightness: (json['brightness'] as num).toDouble(),
      contrast: (json['contrast'] as num).toDouble(),
      noiseLevel: (json['noiseLevel'] as num).toDouble(),
      resolution: (json['resolution'] as num).toDouble(),
      compression: (json['compression'] as num).toDouble(),
      objectCoverage: (json['objectCoverage'] as num).toDouble(),
      edgeClarity: (json['edgeClarity'] as num).toDouble(),
      overallScore: (json['overallScore'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sharpness': sharpness,
      'brightness': brightness,
      'contrast': contrast,
      'noiseLevel': noiseLevel,
      'resolution': resolution,
      'compression': compression,
      'objectCoverage': objectCoverage,
      'edgeClarity': edgeClarity,
      'overallScore': overallScore,
    };
  }

  QualityLevel get qualityLevel {
    if (overallScore >= 0.9) return QualityLevel.excellent;
    if (overallScore >= 0.7) return QualityLevel.good;
    if (overallScore >= 0.5) return QualityLevel.acceptable;
    if (overallScore >= 0.3) return QualityLevel.poor;
    return QualityLevel.critical;
  }

  bool get isAcceptableForAIAnalysis => overallScore >= 0.4;
  
  bool get shouldProceedWithoutWarning => overallScore >= 0.7;

  List<QualityIssue> getQualityIssues() {
    final issues = <QualityIssue>[];
    
    if (sharpness < 0.5) {
      issues.add(QualityIssue.blur(severity: _getSeverity(sharpness)));
    }
    
    if (brightness < 0.3 || brightness > 0.8) {
      issues.add(QualityIssue.lighting(
        severity: _getSeverity(1.0 - (brightness - 0.55).abs() * 2)
      ));
    }
    
    if (contrast < 0.3) {
      issues.add(QualityIssue.lowContrast(severity: _getSeverity(contrast)));
    }
    
    if (noiseLevel > 0.6) {
      issues.add(QualityIssue.noise(severity: _getSeverity(1.0 - noiseLevel)));
    }
    
    if (resolution < 0.5) {
      issues.add(QualityIssue.resolution(severity: _getSeverity(resolution)));
    }
    
    if (objectCoverage < 0.3) {
      issues.add(QualityIssue.objectSize(severity: _getSeverity(objectCoverage)));
    }
    
    return issues;
  }

  IssueSeverity _getSeverity(double score) {
    if (score >= 0.7) return IssueSeverity.minor;
    if (score >= 0.4) return IssueSeverity.major;
    return IssueSeverity.critical;
  }

  @override
  String toString() => 'ImageQualityMetrics(overall: ${overallScore.toStringAsFixed(2)}, '
      'quality: ${qualityLevel.name})';
}

enum QualityLevel {
  excellent, // 0.9-1.0 - Perfektní pro AI analýzu
  good,      // 0.7-0.89 - Velmi dobrá pro AI analýzu  
  acceptable,// 0.5-0.69 - Přijatelná pro AI analýzu
  poor,      // 0.3-0.49 - Špatná, doporučeno přefotit
  critical   // 0.0-0.29 - Kriticky špatná, nutno přefotit
}

enum IssueSeverity { minor, major, critical }

class QualityIssue {
  final QualityIssueType type;
  final IssueSeverity severity;
  final String description;
  final List<String> recommendations;

  const QualityIssue({
    required this.type,
    required this.severity,
    required this.description,
    required this.recommendations,
  });

  factory QualityIssue.blur({required IssueSeverity severity}) => QualityIssue(
    type: QualityIssueType.blur,
    severity: severity,
    description: 'Snímek je rozmazaný nebo neostrý',
    recommendations: [
      'Použijte autofocus před pořízením snímku',
      'Stabilizujte ruce nebo použijte stativ',
      'Zkontrolujte čistotu objektivu',
      'Přibližte se k objektu pro lepší ostrost'
    ],
  );

  factory QualityIssue.lighting({required IssueSeverity severity}) => QualityIssue(
    type: QualityIssueType.lighting,
    severity: severity,
    description: 'Nevhodné osvětlení snímku',
    recommendations: [
      'Zlepšete osvětlení prostoru',
      'Vyhněte se přímému světlu a stínům',
      'Použijte rovnoměrné osvětlení',
      'Otočte objekt pro lepší osvětlení'
    ],
  );

  factory QualityIssue.lowContrast({required IssueSeverity severity}) => QualityIssue(
    type: QualityIssueType.contrast,
    severity: severity,
    description: 'Nízký kontrast snímku',
    recommendations: [
      'Použijte kontrastní pozadí',
      'Zlepšete osvětlení pro větší kontrast',
      'Upravte nastavení kamery'
    ],
  );

  factory QualityIssue.noise({required IssueSeverity severity}) => QualityIssue(
    type: QualityIssueType.noise,
    severity: severity,
    description: 'Vysoká úroveň šumu v snímku',
    recommendations: [
      'Zlepšete osvětlení pro nižší ISO',
      'Použijte lepší kvalitu kamery',
      'Snižte digitální přiblížení'
    ],
  );

  factory QualityIssue.resolution({required IssueSeverity severity}) => QualityIssue(
    type: QualityIssueType.resolution,
    severity: severity,
    description: 'Nedostatečné rozlišení snímku',
    recommendations: [
      'Zvyšte rozlišení kamery',
      'Přibližte se k objektu',
      'Použijte lepší kameru'
    ],
  );

  factory QualityIssue.objectSize({required IssueSeverity severity}) => QualityIssue(
    type: QualityIssueType.objectSize,
    severity: severity,
    description: 'Objekt zabírá příliš málo prostoru na snímku',
    recommendations: [
      'Přibližte se k objektu',
      'Použijte zoom pro větší detail',
      'Přemístěte objekt blíže ke kameře'
    ],
  );

  factory QualityIssue.fromJson(Map<String, dynamic> json) {
    return QualityIssue(
      type: QualityIssueType.values.firstWhere((e) => e.name == json['type']),
      severity: IssueSeverity.values.firstWhere((e) => e.name == json['severity']),
      description: json['description'] as String,
      recommendations: (json['recommendations'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'severity': severity.name,
      'description': description,
      'recommendations': recommendations,
    };
  }
}

enum QualityIssueType {
  blur,
  lighting,
  contrast,
  noise,
  resolution,
  objectSize
}