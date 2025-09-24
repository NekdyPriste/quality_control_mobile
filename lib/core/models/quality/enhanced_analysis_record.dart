import 'dart:typed_data';
import 'image_quality_metrics.dart';
import 'enhanced_confidence_score.dart';
import 'action_recommendation.dart';
import 'analysis_feedback.dart';
import '../quality_report.dart';

class EnhancedAnalysisRecord {
  final String id;
  final DateTime createdAt;
  final DateTime? completedAt;
  final AnalysisStatus status;
  
  // Vstupní data
  final AnalysisInputData inputData;
  
  // Pre-analýza kvalita
  final ImageQualityMetrics? referenceImageQuality;
  final ImageQualityMetrics? partImageQuality;
  
  // Enhanced Confidence System
  final EnhancedConfidenceScore? confidenceScore;
  final ActionRecommendation? recommendation;
  
  // AI Analýza výsledky
  final QualityReport? analysisResult;
  final Duration? processingTime;
  final int? tokensUsed;
  final double? estimatedCost;
  
  // Uživatelský feedback
  final AnalysisFeedback? userFeedback;
  final bool wasRecommendationFollowed;
  
  // Metadata a statistiky
  final AnalysisMetadata metadata;
  final List<AnalysisEvent> events;
  
  // Úložiště obrazů
  final StoredImageData? storedImages;

  const EnhancedAnalysisRecord({
    required this.id,
    required this.createdAt,
    this.completedAt,
    required this.status,
    required this.inputData,
    this.referenceImageQuality,
    this.partImageQuality,
    this.confidenceScore,
    this.recommendation,
    this.analysisResult,
    this.processingTime,
    this.tokensUsed,
    this.estimatedCost,
    this.userFeedback,
    required this.wasRecommendationFollowed,
    required this.metadata,
    required this.events,
    this.storedImages,
  });

  factory EnhancedAnalysisRecord.createNew({
    required String referenceImagePath,
    required String partImagePath,
    required String userId,
    Map<String, dynamic>? additionalContext,
  }) {
    final now = DateTime.now();
    final id = _generateId(now);
    
    return EnhancedAnalysisRecord(
      id: id,
      createdAt: now,
      status: AnalysisStatus.initialized,
      inputData: AnalysisInputData(
        referenceImagePath: referenceImagePath,
        partImagePath: partImagePath,
        userId: userId,
        sessionId: _generateSessionId(),
        additionalContext: additionalContext ?? {},
      ),
      wasRecommendationFollowed: false,
      metadata: AnalysisMetadata(
        version: '1.0.0',
        deviceInfo: {},
        appVersion: '1.0.0+1',
        platform: 'flutter',
      ),
      events: [
        AnalysisEvent.created(now),
      ],
    );
  }

  static String _generateId(DateTime timestamp) {
    final ms = timestamp.millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'analysis_${ms}_$random';
  }

  static String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'session_$timestamp';
  }

  // Aktualizační metody pro postupné naplňování dat
  EnhancedAnalysisRecord withQualityAnalysis({
    required ImageQualityMetrics referenceQuality,
    required ImageQualityMetrics partQuality,
  }) {
    return _copyWith(
      status: AnalysisStatus.qualityAnalyzed,
      referenceImageQuality: referenceQuality,
      partImageQuality: partQuality,
      events: [
        ...events,
        AnalysisEvent.qualityAnalyzed(DateTime.now()),
      ],
    );
  }

  EnhancedAnalysisRecord withConfidenceScore({
    required EnhancedConfidenceScore confidence,
    ActionRecommendation? actionRecommendation,
  }) {
    return _copyWith(
      status: AnalysisStatus.confidenceCalculated,
      confidenceScore: confidence,
      recommendation: actionRecommendation,
      events: [
        ...events,
        AnalysisEvent.confidenceCalculated(DateTime.now()),
      ],
    );
  }

  EnhancedAnalysisRecord withRecommendationFollowed() {
    return _copyWith(
      wasRecommendationFollowed: true,
      events: [
        ...events,
        AnalysisEvent.recommendationFollowed(DateTime.now()),
      ],
    );
  }

  EnhancedAnalysisRecord withAIAnalysisResult({
    required QualityReport result,
    required Duration processingTime,
    int? tokensUsed,
    double? estimatedCost,
  }) {
    return _copyWith(
      status: AnalysisStatus.aiAnalysisCompleted,
      analysisResult: result,
      processingTime: processingTime,
      tokensUsed: tokensUsed,
      estimatedCost: estimatedCost,
      completedAt: DateTime.now(),
      events: [
        ...events,
        AnalysisEvent.aiAnalysisCompleted(DateTime.now()),
      ],
    );
  }

  EnhancedAnalysisRecord withUserFeedback(AnalysisFeedback feedback) {
    return _copyWith(
      status: AnalysisStatus.feedbackReceived,
      userFeedback: feedback,
      events: [
        ...events,
        AnalysisEvent.feedbackReceived(DateTime.now()),
      ],
    );
  }

  EnhancedAnalysisRecord withStoredImages({
    required Uint8List referenceImageData,
    required Uint8List partImageData,
    String? compressionLevel,
  }) {
    return _copyWith(
      storedImages: StoredImageData(
        referenceImageData: referenceImageData,
        partImageData: partImageData,
        compressionLevel: compressionLevel ?? 'medium',
        storedAt: DateTime.now(),
      ),
      events: [
        ...events,
        AnalysisEvent.imagesStored(DateTime.now()),
      ],
    );
  }

  EnhancedAnalysisRecord withError(String error) {
    return _copyWith(
      status: AnalysisStatus.failed,
      events: [
        ...events,
        AnalysisEvent.error(DateTime.now(), error),
      ],
    );
  }

  // Utility metody
  Duration get totalDuration => completedAt != null 
      ? completedAt!.difference(createdAt)
      : DateTime.now().difference(createdAt);

  bool get isCompleted => status == AnalysisStatus.aiAnalysisCompleted || 
                         status == AnalysisStatus.feedbackReceived;

  bool get hasFeedback => userFeedback != null;

  bool get wasSuccessful => isCompleted && 
                           (userFeedback?.isPositiveFeedback ?? true);

  double get confidenceAccuracy {
    if (confidenceScore == null || userFeedback == null) return 0.0;
    return 1.0 - userFeedback!.confidenceValidation.deviation;
  }

  /// Získá skóre kvality celé analýzy (0.0-1.0)
  double get overallQualityScore {
    double score = 0.0;
    int factors = 0;

    // Kvalita vstupních snímků
    if (referenceImageQuality != null) {
      score += referenceImageQuality!.overallScore;
      factors++;
    }
    if (partImageQuality != null) {
      score += partImageQuality!.overallScore;
      factors++;
    }

    // Confidence score
    if (confidenceScore != null) {
      score += confidenceScore!.overallConfidence;
      factors++;
    }

    // Uživatelský feedback
    if (userFeedback != null) {
      final feedbackScore = _feedbackToScore(userFeedback!.accuracyRating);
      score += feedbackScore;
      factors++;
    }

    return factors > 0 ? score / factors : 0.0;
  }

  double _feedbackToScore(AccuracyRating rating) {
    switch (rating) {
      case AccuracyRating.excellent:
        return 1.0;
      case AccuracyRating.veryGood:
        return 0.9;
      case AccuracyRating.good:
        return 0.75;
      case AccuracyRating.acceptable:
        return 0.6;
      case AccuracyRating.poor:
        return 0.3;
      case AccuracyRating.veryPoor:
        return 0.1;
    }
  }

  /// Získá seznam doporučení pro zlepšení na základě této analýzy
  List<ImprovementSuggestion> getImprovementSuggestions() {
    final suggestions = <ImprovementSuggestion>[];

    // Na základě kvality snímků
    if (referenceImageQuality != null && 
        referenceImageQuality!.overallScore < 0.7) {
      suggestions.add(ImprovementSuggestion(
        category: ImprovementCategory.imageQuality,
        priority: SuggestionPriority.high,
        description: 'Zlepšit kvalitu referenčních snímků',
        expectedImpact: 0.3,
      ));
    }

    // Na základě confidence score
    if (confidenceScore != null && 
        confidenceScore!.overallConfidence < 0.6) {
      suggestions.add(ImprovementSuggestion(
        category: ImprovementCategory.analysisConfidence,
        priority: SuggestionPriority.medium,
        description: 'Zlepšit podmínky pro vyšší jistotu analýzy',
        expectedImpact: 0.25,
      ));
    }

    // Na základě uživatelského feedbacku
    if (userFeedback != null) {
      final areas = userFeedback!.getImprovementAreas();
      for (final area in areas) {
        suggestions.add(ImprovementSuggestion(
          category: _mapImprovementArea(area),
          priority: SuggestionPriority.high,
          description: _getAreaDescription(area),
          expectedImpact: 0.4,
        ));
      }
    }

    return suggestions;
  }

  ImprovementCategory _mapImprovementArea(ImprovementArea area) {
    switch (area) {
      case ImprovementArea.imageQualityAssessment:
      case ImprovementArea.blurDetection:
      case ImprovementArea.lightingAssessment:
        return ImprovementCategory.imageQuality;
      case ImprovementArea.modelAccuracy:
      case ImprovementArea.defectDetection:
        return ImprovementCategory.modelPerformance;
      case ImprovementArea.confidenceCalibration:
        return ImprovementCategory.analysisConfidence;
      case ImprovementArea.userInterface:
        return ImprovementCategory.userExperience;
      case ImprovementArea.responseTime:
        return ImprovementCategory.performance;
    }
  }

  String _getAreaDescription(ImprovementArea area) {
    switch (area) {
      case ImprovementArea.imageQualityAssessment:
        return 'Zlepšit hodnocení kvality snímků';
      case ImprovementArea.blurDetection:
        return 'Zlepšit detekci rozmazání';
      case ImprovementArea.lightingAssessment:
        return 'Zlepšit hodnocení osvětlení';
      case ImprovementArea.modelAccuracy:
        return 'Zvýšit přesnost AI modelu';
      case ImprovementArea.defectDetection:
        return 'Zlepšit detekci vad';
      case ImprovementArea.confidenceCalibration:
        return 'Kalibrovat confidence skóre';
      case ImprovementArea.userInterface:
        return 'Vylepšit uživatelské rozhraní';
      case ImprovementArea.responseTime:
        return 'Zrychlit odezvu systému';
    }
  }

  EnhancedAnalysisRecord _copyWith({
    AnalysisStatus? status,
    ImageQualityMetrics? referenceImageQuality,
    ImageQualityMetrics? partImageQuality,
    EnhancedConfidenceScore? confidenceScore,
    ActionRecommendation? recommendation,
    QualityReport? analysisResult,
    Duration? processingTime,
    int? tokensUsed,
    double? estimatedCost,
    AnalysisFeedback? userFeedback,
    bool? wasRecommendationFollowed,
    DateTime? completedAt,
    List<AnalysisEvent>? events,
    StoredImageData? storedImages,
  }) {
    return EnhancedAnalysisRecord(
      id: id,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      inputData: inputData,
      referenceImageQuality: referenceImageQuality ?? this.referenceImageQuality,
      partImageQuality: partImageQuality ?? this.partImageQuality,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      recommendation: recommendation ?? this.recommendation,
      analysisResult: analysisResult ?? this.analysisResult,
      processingTime: processingTime ?? this.processingTime,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      userFeedback: userFeedback ?? this.userFeedback,
      wasRecommendationFollowed: wasRecommendationFollowed ?? this.wasRecommendationFollowed,
      metadata: metadata,
      events: events ?? this.events,
      storedImages: storedImages ?? this.storedImages,
    );
  }

  factory EnhancedAnalysisRecord.fromJson(Map<String, dynamic> json) {
    return EnhancedAnalysisRecord(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      status: AnalysisStatus.values.firstWhere((e) => e.name == json['status']),
      inputData: AnalysisInputData.fromJson(json['inputData'] as Map<String, dynamic>),
      referenceImageQuality: json['referenceImageQuality'] != null 
          ? ImageQualityMetrics.fromJson(json['referenceImageQuality'] as Map<String, dynamic>) 
          : null,
      partImageQuality: json['partImageQuality'] != null 
          ? ImageQualityMetrics.fromJson(json['partImageQuality'] as Map<String, dynamic>) 
          : null,
      confidenceScore: json['confidenceScore'] != null 
          ? EnhancedConfidenceScore.fromJson(json['confidenceScore'] as Map<String, dynamic>) 
          : null,
      recommendation: json['recommendation'] != null 
          ? ActionRecommendation.fromJson(json['recommendation'] as Map<String, dynamic>) 
          : null,
      analysisResult: json['analysisResult'] != null 
          ? QualityReport.fromJson(json['analysisResult'] as Map<String, dynamic>) 
          : null,
      processingTime: json['processingTimeMs'] != null 
          ? Duration(milliseconds: json['processingTimeMs'] as int) 
          : null,
      tokensUsed: json['tokensUsed'] as int?,
      estimatedCost: json['estimatedCost'] != null ? (json['estimatedCost'] as num).toDouble() : null,
      userFeedback: json['userFeedback'] != null 
          ? AnalysisFeedback.fromJson(json['userFeedback'] as Map<String, dynamic>) 
          : null,
      wasRecommendationFollowed: json['wasRecommendationFollowed'] as bool,
      metadata: AnalysisMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      events: (json['events'] as List<dynamic>)
          .map((e) => AnalysisEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      storedImages: json['storedImages'] != null 
          ? StoredImageData.fromJson(json['storedImages'] as Map<String, dynamic>) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'status': status.name,
      'inputData': inputData.toJson(),
      'referenceImageQuality': referenceImageQuality?.toJson(),
      'partImageQuality': partImageQuality?.toJson(),
      'confidenceScore': confidenceScore?.toJson(),
      'recommendation': recommendation?.toJson(),
      'analysisResult': analysisResult?.toJson(),
      'processingTimeMs': processingTime?.inMilliseconds,
      'tokensUsed': tokensUsed,
      'estimatedCost': estimatedCost,
      'userFeedback': userFeedback?.toJson(),
      'wasRecommendationFollowed': wasRecommendationFollowed,
      'metadata': metadata.toJson(),
      'events': events.map((e) => e.toJson()).toList(),
      'storedImages': storedImages?.toJson(),
    };
  }

  @override
  String toString() => 'EnhancedAnalysisRecord('
      'id: $id, '
      'status: ${status.name}, '
      'confidence: ${confidenceScore?.overallConfidence.toStringAsFixed(2) ?? 'N/A'})';
}

enum AnalysisStatus {
  initialized,              // Vytvořeno, čeká na zpracování
  qualityAnalyzed,         // Kvalita snímků analyzována
  confidenceCalculated,    // Confidence score vypočítán
  recommendationGenerated, // Doporučení vygenerováno
  aiAnalysisStarted,      // AI analýza spuštěna
  aiAnalysisCompleted,    // AI analýza dokončena
  feedbackReceived,       // Uživatelský feedback přijat
  archived,               // Archivováno
  failed                  // Neúspěšné
}

class AnalysisInputData {
  final String referenceImagePath;
  final String partImagePath;
  final String userId;
  final String sessionId;
  final Map<String, dynamic> additionalContext;

  const AnalysisInputData({
    required this.referenceImagePath,
    required this.partImagePath,
    required this.userId,
    required this.sessionId,
    required this.additionalContext,
  });

  factory AnalysisInputData.fromJson(Map<String, dynamic> json) {
    return AnalysisInputData(
      referenceImagePath: json['referenceImagePath'] as String,
      partImagePath: json['partImagePath'] as String,
      userId: json['userId'] as String,
      sessionId: json['sessionId'] as String,
      additionalContext: Map<String, dynamic>.from(json['additionalContext'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'referenceImagePath': referenceImagePath,
      'partImagePath': partImagePath,
      'userId': userId,
      'sessionId': sessionId,
      'additionalContext': additionalContext,
    };
  }
}

class AnalysisMetadata {
  final String version;
  final Map<String, dynamic> deviceInfo;
  final String appVersion;
  final String platform;

  const AnalysisMetadata({
    required this.version,
    required this.deviceInfo,
    required this.appVersion,
    required this.platform,
  });

  factory AnalysisMetadata.fromJson(Map<String, dynamic> json) {
    return AnalysisMetadata(
      version: json['version'] as String,
      deviceInfo: Map<String, dynamic>.from(json['deviceInfo'] as Map),
      appVersion: json['appVersion'] as String,
      platform: json['platform'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'deviceInfo': deviceInfo,
      'appVersion': appVersion,
      'platform': platform,
    };
  }
}

class AnalysisEvent {
  final DateTime timestamp;
  final AnalysisEventType type;
  final String description;
  final Map<String, dynamic>? data;

  const AnalysisEvent({
    required this.timestamp,
    required this.type,
    required this.description,
    this.data,
  });

  factory AnalysisEvent.created(DateTime timestamp) => AnalysisEvent(
    timestamp: timestamp,
    type: AnalysisEventType.created,
    description: 'Analýza vytvořena',
  );

  factory AnalysisEvent.qualityAnalyzed(DateTime timestamp) => AnalysisEvent(
    timestamp: timestamp,
    type: AnalysisEventType.qualityAnalyzed,
    description: 'Kvalita snímků analyzována',
  );

  factory AnalysisEvent.confidenceCalculated(DateTime timestamp) => AnalysisEvent(
    timestamp: timestamp,
    type: AnalysisEventType.confidenceCalculated,
    description: 'Confidence score vypočítán',
  );

  factory AnalysisEvent.recommendationFollowed(DateTime timestamp) => AnalysisEvent(
    timestamp: timestamp,
    type: AnalysisEventType.recommendationFollowed,
    description: 'Doporučení následováno uživatelem',
  );

  factory AnalysisEvent.aiAnalysisCompleted(DateTime timestamp) => AnalysisEvent(
    timestamp: timestamp,
    type: AnalysisEventType.aiAnalysisCompleted,
    description: 'AI analýza dokončena',
  );

  factory AnalysisEvent.feedbackReceived(DateTime timestamp) => AnalysisEvent(
    timestamp: timestamp,
    type: AnalysisEventType.feedbackReceived,
    description: 'Uživatelský feedback přijat',
  );

  factory AnalysisEvent.imagesStored(DateTime timestamp) => AnalysisEvent(
    timestamp: timestamp,
    type: AnalysisEventType.imagesStored,
    description: 'Snímky uloženy do databáze',
  );

  factory AnalysisEvent.error(DateTime timestamp, String error) => AnalysisEvent(
    timestamp: timestamp,
    type: AnalysisEventType.error,
    description: 'Chyba: $error',
    data: {'error': error},
  );

  factory AnalysisEvent.fromJson(Map<String, dynamic> json) {
    return AnalysisEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: AnalysisEventType.values.firstWhere((e) => e.name == json['type']),
      description: json['description'] as String,
      data: json['data'] != null ? Map<String, dynamic>.from(json['data'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'description': description,
      'data': data,
    };
  }
}

enum AnalysisEventType {
  created,
  qualityAnalyzed,
  confidenceCalculated,
  recommendationGenerated,
  recommendationFollowed,
  aiAnalysisStarted,
  aiAnalysisCompleted,
  feedbackReceived,
  imagesStored,
  archived,
  error
}

class StoredImageData {
  final Uint8List referenceImageData;
  final Uint8List partImageData;
  final String compressionLevel;
  final DateTime storedAt;

  const StoredImageData({
    required this.referenceImageData,
    required this.partImageData,
    required this.compressionLevel,
    required this.storedAt,
  });

  int get totalSize => referenceImageData.length + partImageData.length;
  
  String get sizeDescription {
    final mb = totalSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  factory StoredImageData.fromJson(Map<String, dynamic> json) {
    return StoredImageData(
      referenceImageData: Uint8List.fromList((json['referenceImageData'] as List<dynamic>).cast<int>()),
      partImageData: Uint8List.fromList((json['partImageData'] as List<dynamic>).cast<int>()),
      compressionLevel: json['compressionLevel'] as String,
      storedAt: DateTime.parse(json['storedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'referenceImageData': referenceImageData.toList(),
      'partImageData': partImageData.toList(),
      'compressionLevel': compressionLevel,
      'storedAt': storedAt.toIso8601String(),
    };
  }
}

class ImprovementSuggestion {
  final ImprovementCategory category;
  final SuggestionPriority priority;
  final String description;
  final double expectedImpact; // 0.0-1.0

  const ImprovementSuggestion({
    required this.category,
    required this.priority,
    required this.description,
    required this.expectedImpact,
  });

  factory ImprovementSuggestion.fromJson(Map<String, dynamic> json) {
    return ImprovementSuggestion(
      category: ImprovementCategory.values.firstWhere((e) => e.name == json['category']),
      priority: SuggestionPriority.values.firstWhere((e) => e.name == json['priority']),
      description: json['description'] as String,
      expectedImpact: (json['expectedImpact'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category.name,
      'priority': priority.name,
      'description': description,
      'expectedImpact': expectedImpact,
    };
  }
}

enum ImprovementCategory {
  imageQuality,        // Kvalita snímků
  analysisConfidence,  // Jistota analýzy
  modelPerformance,    // Výkon modelu
  userExperience,      // Uživatelský zážitek
  performance          // Rychlost a výkon
}