import 'batch_enhanced_result.dart';
import 'quality_report.dart';
import 'comparison_result.dart';

/// Overall analýza kompletního batch s Enhanced Analysis
class BatchOverallAnalysis {
  final String batchId;
  final DateTime generatedAt;
  final Duration totalProcessingTime;

  /// Aggregate confidence a quality metrics
  final double overallConfidence;
  final QualityStatus overallStatus;
  final BatchQualityTrend qualityTrend;

  /// Statistiky batch výsledků
  final BatchStatistics statistics;

  /// Kritické problémy a doporučení
  final List<String> criticalIssues;
  final List<BatchRecommendation> recommendations;
  final String executiveSummary;

  /// Quality metrics breakdown
  final Map<String, double> qualityMetrics;

  /// Performance a cost analytics
  final BatchPerformanceMetrics performanceMetrics;

  /// Trending and patterns
  final List<BatchPattern> identifiedPatterns;

  const BatchOverallAnalysis({
    required this.batchId,
    required this.generatedAt,
    required this.totalProcessingTime,
    required this.overallConfidence,
    required this.overallStatus,
    required this.qualityTrend,
    required this.statistics,
    required this.criticalIssues,
    required this.recommendations,
    required this.executiveSummary,
    required this.qualityMetrics,
    required this.performanceMetrics,
    required this.identifiedPatterns,
  });

  /// Vytvořit overall analýzu z batch enhanced results
  factory BatchOverallAnalysis.fromBatchResults({
    required String batchId,
    required List<BatchEnhancedResult> results,
    required Duration totalProcessingTime,
  }) {
    final completedResults = results.where((r) => r.isCompleted).toList();
    final statistics = BatchStatistics.fromResults(results);

    // Vypočítá overall confidence jako vážený průměr
    final overallConfidence = _calculateOverallConfidence(completedResults);

    // Určí overall status na základě převažujícího výsledku
    final overallStatus = _determineOverallStatus(completedResults, statistics);

    // Analýza trendů kvality
    final qualityTrend = _analyzeQualityTrend(completedResults);

    // Identifikuje kritické problémy
    final criticalIssues = _identifyCriticalIssues(completedResults);

    // Generuje doporučení
    final recommendations = _generateRecommendations(completedResults, statistics);

    // Vytvoří executive summary
    final executiveSummary = _generateExecutiveSummary(
      statistics, overallStatus, overallConfidence, criticalIssues.length
    );

    // Quality metrics breakdown
    final qualityMetrics = _calculateQualityMetrics(completedResults);

    // Performance metrics
    final performanceMetrics = BatchPerformanceMetrics.fromResults(
      results, totalProcessingTime
    );

    // Pattern identification
    final patterns = _identifyPatterns(completedResults);

    return BatchOverallAnalysis(
      batchId: batchId,
      generatedAt: DateTime.now(),
      totalProcessingTime: totalProcessingTime,
      overallConfidence: overallConfidence,
      overallStatus: overallStatus,
      qualityTrend: qualityTrend,
      statistics: statistics,
      criticalIssues: criticalIssues,
      recommendations: recommendations,
      executiveSummary: executiveSummary,
      qualityMetrics: qualityMetrics,
      performanceMetrics: performanceMetrics,
      identifiedPatterns: patterns,
    );
  }

  // Helper methods pro generování analýzy
  static double _calculateOverallConfidence(List<BatchEnhancedResult> results) {
    if (results.isEmpty) return 0.0;

    double totalWeightedConfidence = 0.0;
    double totalWeight = 0.0;

    for (final result in results) {
      final confidence = result.confidenceScore ?? result.basicResult?.confidenceScore ?? 0.0;
      final weight = result.combinedQualityScore; // Použije combined score jako váhu

      totalWeightedConfidence += confidence * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? totalWeightedConfidence / totalWeight : 0.0;
  }

  static QualityStatus _determineOverallStatus(
    List<BatchEnhancedResult> results,
    BatchStatistics stats
  ) {
    if (results.isEmpty) return QualityStatus.fail;

    final passPercentage = stats.successRate;

    if (passPercentage >= 0.9) return QualityStatus.pass;
    if (passPercentage >= 0.7) return QualityStatus.warning;
    return QualityStatus.fail;
  }

  static BatchQualityTrend _analyzeQualityTrend(List<BatchEnhancedResult> results) {
    if (results.length < 3) return BatchQualityTrend.stable;

    // Analyzuje trend kvality během batch processing
    final sortedResults = List<BatchEnhancedResult>.from(results)
      ..sort((a, b) => a.processedAt.compareTo(b.processedAt));

    final firstHalf = sortedResults.take(sortedResults.length ~/ 2).toList();
    final secondHalf = sortedResults.skip(sortedResults.length ~/ 2).toList();

    final firstHalfAvg = firstHalf
        .map((r) => r.combinedQualityScore)
        .reduce((a, b) => a + b) / firstHalf.length;
    final secondHalfAvg = secondHalf
        .map((r) => r.combinedQualityScore)
        .reduce((a, b) => a + b) / secondHalf.length;

    final difference = secondHalfAvg - firstHalfAvg;

    if (difference > 0.1) return BatchQualityTrend.improving;
    if (difference < -0.1) return BatchQualityTrend.declining;
    return BatchQualityTrend.stable;
  }

  static List<String> _identifyCriticalIssues(List<BatchEnhancedResult> results) {
    final issues = <String>[];

    // Vysoká míra selhání
    final failedCount = results.where((r) =>
      r.overallQuality == QualityStatus.fail).length;
    if (failedCount > results.length * 0.3) {
      issues.add('Vysoká míra selhání: ${(failedCount / results.length * 100).toStringAsFixed(1)}%');
    }

    // Nízká průměrná confidence
    final avgConfidence = results
        .where((r) => r.confidenceScore != null)
        .map((r) => r.confidenceScore!)
        .fold(0.0, (a, b) => a + b) / results.length;
    if (avgConfidence < 0.6) {
      issues.add('Nízká průměrná jistota analýzy: ${(avgConfidence * 100).toStringAsFixed(1)}%');
    }

    // Časté chyby zpracování
    final errorCount = results.where((r) => r.isFailed).length;
    if (errorCount > results.length * 0.1) {
      issues.add('Časté chyby zpracování: $errorCount z ${results.length}');
    }

    return issues;
  }

  static List<BatchRecommendation> _generateRecommendations(
    List<BatchEnhancedResult> results,
    BatchStatistics statistics,
  ) {
    final recommendations = <BatchRecommendation>[];

    // Doporučení na základě success rate
    if (statistics.successRate < 0.7) {
      recommendations.add(BatchRecommendation(
        priority: RecommendationPriority.high,
        title: 'Zlepšit kvalitu vstupních snímků',
        description: 'Nízká úspěšnost analýzy naznačuje problémy s kvalitou vstupních dat',
        actionItems: [
          'Zkontrolovat osvětlení při fotografování',
          'Ověřit ostrost snímků',
          'Zlepšit pozicování dílu při fotografování',
        ],
      ));
    }

    // Doporučení na základě processing time
    if (results.any((r) => r.processingTime.inSeconds > 30)) {
      recommendations.add(BatchRecommendation(
        priority: RecommendationPriority.medium,
        title: 'Optimalizovat výkon analýzy',
        description: 'Některé analýzy trvají příliš dlouho',
        actionItems: [
          'Zvážit snížení rozlišení snímků',
          'Používat méně složité analýzy pro rutinní kontroly',
          'Implementovat paralelní zpracování',
        ],
      ));
    }

    return recommendations;
  }

  static String _generateExecutiveSummary(
    BatchStatistics statistics,
    QualityStatus overallStatus,
    double overallConfidence,
    int criticalIssuesCount,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('📊 BATCH ENHANCED ANALYSIS SUMMARY');
    buffer.writeln();
    buffer.writeln('Celkem analyzováno: ${statistics.totalProcessed} párů snímků');
    buffer.writeln('Úspěšnost: ${(statistics.successRate * 100).toStringAsFixed(1)}%');
    buffer.writeln('Průměrná jistota: ${(overallConfidence * 100).toStringAsFixed(1)}%');
    buffer.writeln('Overall status: ${_getStatusEmoji(overallStatus)} ${overallStatus.name.toUpperCase()}');
    buffer.writeln();

    if (criticalIssuesCount > 0) {
      buffer.writeln('⚠️ Kritické problémy: $criticalIssuesCount');
      buffer.writeln('Doporučujeme okamžitou pozornost.');
    } else {
      buffer.writeln('✅ Žádné kritické problémy nebyly identifikovány.');
    }

    return buffer.toString();
  }

  static String _getStatusEmoji(QualityStatus status) {
    switch (status) {
      case QualityStatus.pass: return '✅';
      case QualityStatus.warning: return '⚠️';
      case QualityStatus.fail: return '❌';
    }
  }

  static Map<String, double> _calculateQualityMetrics(List<BatchEnhancedResult> results) {
    if (results.isEmpty) return {};

    return {
      'averageConfidence': results
          .where((r) => r.confidenceScore != null)
          .map((r) => r.confidenceScore!)
          .fold(0.0, (a, b) => a + b) / results.length,
      'averageProcessingTime': results
          .map((r) => r.processingTime.inMilliseconds.toDouble())
          .fold(0.0, (a, b) => a + b) / results.length,
      'passRate': results.where((r) => r.overallQuality == QualityStatus.pass).length / results.length,
      'warningRate': results.where((r) => r.overallQuality == QualityStatus.warning).length / results.length,
      'failRate': results.where((r) => r.overallQuality == QualityStatus.fail).length / results.length,
    };
  }

  static List<BatchPattern> _identifyPatterns(List<BatchEnhancedResult> results) {
    final patterns = <BatchPattern>[];

    // Pattern: Vysoká míra selhání u specifického part type
    final partTypeFailures = <PartType, int>{};
    for (final result in results) {
      if (result.overallQuality == QualityStatus.fail) {
        partTypeFailures[result.partType] = (partTypeFailures[result.partType] ?? 0) + 1;
      }
    }

    for (final entry in partTypeFailures.entries) {
      final totalForType = results.where((r) => r.partType == entry.key).length;
      final failureRate = entry.value / totalForType;

      if (failureRate > 0.5) {
        patterns.add(BatchPattern(
          type: PatternType.partTypeFailure,
          description: 'Vysoká míra selhání u ${entry.key.name}: ${(failureRate * 100).toStringAsFixed(1)}%',
          confidence: failureRate,
          affectedItems: entry.value,
        ));
      }
    }

    return patterns;
  }

  factory BatchOverallAnalysis.fromJson(Map<String, dynamic> json) {
    return BatchOverallAnalysis(
      batchId: json['batchId'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      totalProcessingTime: Duration(milliseconds: json['totalProcessingTimeMs'] as int),
      overallConfidence: (json['overallConfidence'] as num).toDouble(),
      overallStatus: QualityStatus.values.firstWhere((e) => e.name == json['overallStatus']),
      qualityTrend: BatchQualityTrend.values.firstWhere((e) => e.name == json['qualityTrend']),
      statistics: BatchStatistics.fromJson(json['statistics'] as Map<String, dynamic>),
      criticalIssues: (json['criticalIssues'] as List<dynamic>).cast<String>(),
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((e) => BatchRecommendation.fromJson(e as Map<String, dynamic>))
          .toList(),
      executiveSummary: json['executiveSummary'] as String,
      qualityMetrics: Map<String, double>.from(json['qualityMetrics'] as Map),
      performanceMetrics: BatchPerformanceMetrics.fromJson(json['performanceMetrics'] as Map<String, dynamic>),
      identifiedPatterns: (json['identifiedPatterns'] as List<dynamic>)
          .map((e) => BatchPattern.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'batchId': batchId,
      'generatedAt': generatedAt.toIso8601String(),
      'totalProcessingTimeMs': totalProcessingTime.inMilliseconds,
      'overallConfidence': overallConfidence,
      'overallStatus': overallStatus.name,
      'qualityTrend': qualityTrend.name,
      'statistics': statistics.toJson(),
      'criticalIssues': criticalIssues,
      'recommendations': recommendations.map((e) => e.toJson()).toList(),
      'executiveSummary': executiveSummary,
      'qualityMetrics': qualityMetrics,
      'performanceMetrics': performanceMetrics.toJson(),
      'identifiedPatterns': identifiedPatterns.map((e) => e.toJson()).toList(),
    };
  }
}

class BatchStatistics {
  final int totalProcessed;
  final int successfulCount;
  final int warningCount;
  final int failedCount;
  final int errorCount;
  final double successRate;
  final double averageConfidence;

  const BatchStatistics({
    required this.totalProcessed,
    required this.successfulCount,
    required this.warningCount,
    required this.failedCount,
    required this.errorCount,
    required this.successRate,
    required this.averageConfidence,
  });

  factory BatchStatistics.fromResults(List<BatchEnhancedResult> results) {
    final totalProcessed = results.length;
    final successfulCount = results.where((r) => r.overallQuality == QualityStatus.pass).length;
    final warningCount = results.where((r) => r.overallQuality == QualityStatus.warning).length;
    final failedCount = results.where((r) => r.overallQuality == QualityStatus.fail).length;
    final errorCount = results.where((r) => r.isFailed).length;

    final successRate = totalProcessed > 0 ? successfulCount / totalProcessed : 0.0;

    final confidenceResults = results.where((r) => r.confidenceScore != null).toList();
    final averageConfidence = confidenceResults.isNotEmpty
        ? confidenceResults.map((r) => r.confidenceScore!).reduce((a, b) => a + b) / confidenceResults.length
        : 0.0;

    return BatchStatistics(
      totalProcessed: totalProcessed,
      successfulCount: successfulCount,
      warningCount: warningCount,
      failedCount: failedCount,
      errorCount: errorCount,
      successRate: successRate,
      averageConfidence: averageConfidence,
    );
  }

  factory BatchStatistics.fromJson(Map<String, dynamic> json) {
    return BatchStatistics(
      totalProcessed: json['totalProcessed'] as int,
      successfulCount: json['successfulCount'] as int,
      warningCount: json['warningCount'] as int,
      failedCount: json['failedCount'] as int,
      errorCount: json['errorCount'] as int,
      successRate: (json['successRate'] as num).toDouble(),
      averageConfidence: (json['averageConfidence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalProcessed': totalProcessed,
      'successfulCount': successfulCount,
      'warningCount': warningCount,
      'failedCount': failedCount,
      'errorCount': errorCount,
      'successRate': successRate,
      'averageConfidence': averageConfidence,
    };
  }
}

class BatchPerformanceMetrics {
  final Duration totalProcessingTime;
  final Duration averageProcessingTime;
  final int totalTokensUsed;
  final double totalEstimatedCost;
  final double throughputPerHour;

  const BatchPerformanceMetrics({
    required this.totalProcessingTime,
    required this.averageProcessingTime,
    required this.totalTokensUsed,
    required this.totalEstimatedCost,
    required this.throughputPerHour,
  });

  factory BatchPerformanceMetrics.fromResults(
    List<BatchEnhancedResult> results,
    Duration totalTime
  ) {
    final completedResults = results.where((r) => r.isCompleted).toList();

    final averageTime = completedResults.isNotEmpty
        ? Duration(
            milliseconds: completedResults
                .map((r) => r.processingTime.inMilliseconds)
                .reduce((a, b) => a + b) ~/ completedResults.length
          )
        : Duration.zero;

    final totalTokens = completedResults
        .where((r) => r.tokensUsed != null)
        .map((r) => r.tokensUsed!)
        .fold(0, (a, b) => a + b);

    final totalCost = completedResults
        .where((r) => r.estimatedCost != null)
        .map((r) => r.estimatedCost!)
        .fold(0.0, (a, b) => a + b);

    final throughput = totalTime.inHours > 0
        ? completedResults.length / totalTime.inHours
        : 0.0;

    return BatchPerformanceMetrics(
      totalProcessingTime: totalTime,
      averageProcessingTime: averageTime,
      totalTokensUsed: totalTokens,
      totalEstimatedCost: totalCost,
      throughputPerHour: throughput,
    );
  }

  factory BatchPerformanceMetrics.fromJson(Map<String, dynamic> json) {
    return BatchPerformanceMetrics(
      totalProcessingTime: Duration(milliseconds: json['totalProcessingTimeMs'] as int),
      averageProcessingTime: Duration(milliseconds: json['averageProcessingTimeMs'] as int),
      totalTokensUsed: json['totalTokensUsed'] as int,
      totalEstimatedCost: (json['totalEstimatedCost'] as num).toDouble(),
      throughputPerHour: (json['throughputPerHour'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalProcessingTimeMs': totalProcessingTime.inMilliseconds,
      'averageProcessingTimeMs': averageProcessingTime.inMilliseconds,
      'totalTokensUsed': totalTokensUsed,
      'totalEstimatedCost': totalEstimatedCost,
      'throughputPerHour': throughputPerHour,
    };
  }
}

class BatchRecommendation {
  final RecommendationPriority priority;
  final String title;
  final String description;
  final List<String> actionItems;

  const BatchRecommendation({
    required this.priority,
    required this.title,
    required this.description,
    required this.actionItems,
  });

  factory BatchRecommendation.fromJson(Map<String, dynamic> json) {
    return BatchRecommendation(
      priority: RecommendationPriority.values.firstWhere((e) => e.name == json['priority']),
      title: json['title'] as String,
      description: json['description'] as String,
      actionItems: (json['actionItems'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'priority': priority.name,
      'title': title,
      'description': description,
      'actionItems': actionItems,
    };
  }
}

class BatchPattern {
  final PatternType type;
  final String description;
  final double confidence;
  final int affectedItems;

  const BatchPattern({
    required this.type,
    required this.description,
    required this.confidence,
    required this.affectedItems,
  });

  factory BatchPattern.fromJson(Map<String, dynamic> json) {
    return BatchPattern(
      type: PatternType.values.firstWhere((e) => e.name == json['type']),
      description: json['description'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      affectedItems: json['affectedItems'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'description': description,
      'confidence': confidence,
      'affectedItems': affectedItems,
    };
  }
}

enum BatchQualityTrend {
  improving,  // Kvalita se zlepšuje během batch
  stable,     // Kvalita je stabilní
  declining   // Kvalita se zhoršuje během batch
}

enum RecommendationPriority {
  low,
  medium,
  high,
  critical
}

enum PatternType {
  partTypeFailure,     // Selhání u specifického typu dílu
  timeBasedPattern,    // Vzor založený na čase
  qualityDegradation,  // Degradace kvality
  performanceIssue     // Problémy s výkonem
}