import 'dart:io';
import 'quality_report.dart';
import 'comparison_result.dart';

enum BatchStatus {
  pending,
  processing,
  completed,
  failed
}

class BatchPhotoPair {
  final String id;
  final String referenceImagePath;
  final String partImagePath;
  final PartType partType;
  final String? partSerial;
  final String? notes;
  
  const BatchPhotoPair({
    required this.id,
    required this.referenceImagePath,
    required this.partImagePath,
    required this.partType,
    this.partSerial,
    this.notes,
  });

}

class BatchAnalysisJob {
  final String id;
  final String name;
  final List<BatchPhotoPair> photoPairs;
  final DateTime createdAt;
  final BatchStatus status;
  final int totalPairs;
  final int completedPairs;
  final int failedPairs;
  final List<QualityReport> completedReports;
  final List<String> errorMessages;
  final String? operatorName;
  final String? productionLine;
  final String? batchNumber;
  
  const BatchAnalysisJob({
    required this.id,
    required this.name,
    required this.photoPairs,
    required this.createdAt,
    required this.status,
    required this.totalPairs,
    this.completedPairs = 0,
    this.failedPairs = 0,
    this.completedReports = const [],
    this.errorMessages = const [],
    this.operatorName,
    this.productionLine,
    this.batchNumber,
  });

  double get progressPercentage => 
    totalPairs > 0 ? (completedPairs + failedPairs) / totalPairs * 100 : 0;

  int get passCount => completedReports
    .where((r) => r.comparisonResult.overallQuality == QualityStatus.pass)
    .length;

  int get failCount => completedReports
    .where((r) => r.comparisonResult.overallQuality == QualityStatus.fail)
    .length;

  int get warningCount => completedReports
    .where((r) => r.comparisonResult.overallQuality == QualityStatus.warning)
    .length;


  BatchAnalysisJob copyWith({
    String? id,
    String? name,
    List<BatchPhotoPair>? photoPairs,
    DateTime? createdAt,
    BatchStatus? status,
    int? totalPairs,
    int? completedPairs,
    int? failedPairs,
    List<QualityReport>? completedReports,
    List<String>? errorMessages,
    String? operatorName,
    String? productionLine,
    String? batchNumber,
  }) {
    return BatchAnalysisJob(
      id: id ?? this.id,
      name: name ?? this.name,
      photoPairs: photoPairs ?? this.photoPairs,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      totalPairs: totalPairs ?? this.totalPairs,
      completedPairs: completedPairs ?? this.completedPairs,
      failedPairs: failedPairs ?? this.failedPairs,
      completedReports: completedReports ?? this.completedReports,
      errorMessages: errorMessages ?? this.errorMessages,
      operatorName: operatorName ?? this.operatorName,
      productionLine: productionLine ?? this.productionLine,
      batchNumber: batchNumber ?? this.batchNumber,
    );
  }
}