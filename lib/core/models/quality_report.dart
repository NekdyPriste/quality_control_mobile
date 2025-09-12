import 'package:json_annotation/json_annotation.dart';
import 'comparison_result.dart';

part 'quality_report.g.dart';

enum PartType {
  @JsonValue('VÝLISKY')
  vylisky,
  @JsonValue('OBRÁBĚNÉ') 
  obrabene,
}

@JsonSerializable()
class QualityReport {
  final int id;
  final String referenceImagePath;
  final String partImagePath;
  final PartType partType;
  final DateTime createdAt;
  final ComparisonResult comparisonResult;

  const QualityReport({
    required this.id,
    required this.referenceImagePath,
    required this.partImagePath,
    required this.partType,
    required this.createdAt,
    required this.comparisonResult,
  });

  factory QualityReport.fromJson(Map<String, dynamic> json) =>
      _$QualityReportFromJson(json);

  Map<String, dynamic> toJson() => _$QualityReportToJson(this);

  String get partTypeDisplayName {
    switch (partType) {
      case PartType.vylisky:
        return 'Výlisky';
      case PartType.obrabene:
        return 'Obráběné díly';
    }
  }

  bool get passed => comparisonResult.overallQuality == QualityStatus.pass;
  
  String get statusDisplayName {
    switch (comparisonResult.overallQuality) {
      case QualityStatus.pass:
        return 'Vyhovuje';
      case QualityStatus.fail:
        return 'Nevyhovuje';
      case QualityStatus.warning:
        return 'Upozornění';
    }
  }
}