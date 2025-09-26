import 'quality_report.dart';
import 'comparison_result.dart';
import 'batch_enhanced_result.dart';
import 'batch_overall_analysis.dart';
import 'quality/enhanced_confidence_score.dart';

enum BatchStatus {
  pending,
  processing,
  completed,
  failed
}

enum BatchMode {
  samePart,      // Více fotografií stejného dílu
  multipleParts  // Různé díly v jednom batchi
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

  /// Enhanced Analysis fields
  final bool useEnhancedAnalysis;
  final AnalysisComplexity enhancedComplexity;
  final List<BatchEnhancedResult> enhancedResults;
  final BatchOverallAnalysis? overallAnalysis;
  
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
    this.useEnhancedAnalysis = false,
    this.enhancedComplexity = AnalysisComplexity.moderate,
    this.enhancedResults = const [],
    this.overallAnalysis,
  });

  double get progressPercentage => 
    totalPairs > 0 ? (completedPairs + failedPairs) / totalPairs * 100 : 0;

  int get passCount => completedReports
    .where((r) => r.comparisonResult?.overallQuality == QualityStatus.pass)
    .length;

  int get failCount => completedReports
    .where((r) => r.comparisonResult?.overallQuality == QualityStatus.fail)
    .length;

  int get warningCount => completedReports
    .where((r) => r.comparisonResult?.overallQuality == QualityStatus.warning)
    .length;

  /// Enhanced Analysis getters
  int get enhancedPassCount => enhancedResults
    .where((r) => r.overallQuality == QualityStatus.pass)
    .length;

  int get enhancedFailCount => enhancedResults
    .where((r) => r.overallQuality == QualityStatus.fail)
    .length;

  int get enhancedWarningCount => enhancedResults
    .where((r) => r.overallQuality == QualityStatus.warning)
    .length;

  double get enhancedAverageConfidence {
    final confidenceResults = enhancedResults
      .where((r) => r.confidenceScore != null)
      .toList();

    if (confidenceResults.isEmpty) return 0.0;

    return confidenceResults
      .map((r) => r.confidenceScore!)
      .reduce((a, b) => a + b) / confidenceResults.length;
  }

  Duration get totalEnhancedProcessingTime => enhancedResults
    .map((r) => r.processingTime)
    .fold(Duration.zero, (a, b) => a + b);

  int get totalTokensUsed => enhancedResults
    .where((r) => r.tokensUsed != null)
    .map((r) => r.tokensUsed!)
    .fold(0, (a, b) => a + b);

  double get totalEstimatedCost => enhancedResults
    .where((r) => r.estimatedCost != null)
    .map((r) => r.estimatedCost!)
    .fold(0.0, (a, b) => a + b);


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
    bool? useEnhancedAnalysis,
    AnalysisComplexity? enhancedComplexity,
    List<BatchEnhancedResult>? enhancedResults,
    BatchOverallAnalysis? overallAnalysis,
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
      useEnhancedAnalysis: useEnhancedAnalysis ?? this.useEnhancedAnalysis,
      enhancedComplexity: enhancedComplexity ?? this.enhancedComplexity,
      enhancedResults: enhancedResults ?? this.enhancedResults,
      overallAnalysis: overallAnalysis ?? this.overallAnalysis,
    );
  }
}