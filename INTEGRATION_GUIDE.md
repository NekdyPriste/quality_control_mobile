# Enhanced Confidence System - Integration Guide

## Quick Start

The Enhanced Confidence System provides 4 core models for quality control analysis with AI confidence scoring. All models are production-ready and extensively tested.

## Core Models Overview

### 1. EnhancedConfidenceScore
Multi-factor confidence calculation with weighted scoring system.

```dart
// Calculate confidence score
final confidence = EnhancedConfidenceScore.calculate(
  referenceQuality: referenceImageQuality,
  partQuality: partImageQuality,
  complexity: AnalysisComplexity.moderate,
  history: performanceHistory,
  contextualData: {
    'hasReferenceModel': true,
    'goodLightingConditions': true,
  },
);

// Use in UI
if (confidence.isReliableForDecisionMaking) {
  // Proceed with analysis
} else if (confidence.requiresHumanReview) {
  // Show human review dialog
}
```

### 2. ActionRecommendation
Smart improvement suggestions with step-by-step instructions.

```dart
// Generate recommendations
final recommendation = ActionRecommendation.generateRecommendations(
  referenceQuality: referenceImageQuality,
  partQuality: partImageQuality,
  confidenceScore: confidence,
  issues: qualityIssues,
);

// Display in UI
Text(recommendation.title)
Text(recommendation.description)
ListView.builder(
  itemCount: recommendation.steps.length,
  itemBuilder: (context, index) {
    final step = recommendation.steps[index];
    return ListTile(
      leading: Text('${step.order}'),
      title: Text(step.action),
      subtitle: Text(step.details),
    );
  },
)
```

### 3. AnalysisFeedback
Comprehensive user feedback collection and validation.

```dart
// Collect positive feedback
final feedback = AnalysisFeedback.createPositive(
  analysisId: analysisRecord.id,
  accuracyRating: AccuracyRating.excellent,
  reportedConfidence: confidence.overallConfidence,
  actualConfidence: userRatedConfidence,
  comments: userComments,
);

// Use learning weight for ML
final weight = feedback.learningWeight; // Higher for valuable feedback
```

### 4. EnhancedAnalysisRecord
Complete analysis lifecycle tracking with audit trail.

```dart
// Create new analysis
var record = EnhancedAnalysisRecord.createNew(
  referenceImagePath: referencePath,
  partImagePath: partPath,
  userId: currentUserId,
);

// Update through lifecycle
record = record.withQualityAnalysis(
  referenceQuality: refQuality,
  partQuality: partQuality,
);

record = record.withConfidenceScore(
  confidence: confidence,
  actionRecommendation: recommendation,
);

record = record.withUserFeedback(feedback);
```

## Flutter UI Integration Examples

### Confidence Display Widget

```dart
class ConfidenceDisplay extends StatelessWidget {
  final EnhancedConfidenceScore confidence;
  
  const ConfidenceDisplay({required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          LinearProgressIndicator(
            value: confidence.overallConfidence,
            backgroundColor: Colors.grey[300],
            color: _getConfidenceColor(confidence.confidenceLevel),
          ),
          Text('${(confidence.overallConfidence * 100).toInt()}% Confidence'),
          Text(confidence.confidenceLevel.name.toUpperCase()),
          if (confidence.shouldShowWarnings)
            const Icon(Icons.warning, color: Colors.orange),
        ],
      ),
    );
  }

  Color _getConfidenceColor(ConfidenceLevel level) {
    switch (level) {
      case ConfidenceLevel.veryHigh:
        return Colors.green;
      case ConfidenceLevel.high:
        return Colors.lightGreen;
      case ConfidenceLevel.medium:
        return Colors.orange;
      case ConfidenceLevel.low:
        return Colors.red;
      case ConfidenceLevel.veryLow:
        return Colors.deepOrange;
    }
  }
}
```

### Recommendation Card Widget

```dart
class RecommendationCard extends StatelessWidget {
  final ActionRecommendation recommendation;
  final VoidCallback? onFollow;

  const RecommendationCard({
    required this.recommendation,
    this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: _getPriorityIcon(recommendation.priority),
        title: Text(recommendation.title),
        subtitle: Text(recommendation.description),
        trailing: Text('~${recommendation.estimatedTime.inMinutes}min'),
        children: [
          ...recommendation.steps.map((step) => ListTile(
            leading: CircleAvatar(child: Text('${step.order}')),
            title: Text(step.action),
            subtitle: Text(step.details),
            trailing: Text('${step.estimatedTime.inSeconds}s'),
          )),
          if (recommendation.isActionable)
            ElevatedButton(
              onPressed: onFollow,
              child: const Text('Follow Recommendation'),
            ),
        ],
      ),
    );
  }

  Icon _getPriorityIcon(ActionPriority priority) {
    switch (priority) {
      case ActionPriority.critical:
        return const Icon(Icons.priority_high, color: Colors.red);
      case ActionPriority.high:
        return const Icon(Icons.keyboard_arrow_up, color: Colors.orange);
      case ActionPriority.medium:
        return const Icon(Icons.remove, color: Colors.blue);
      case ActionPriority.low:
        return const Icon(Icons.keyboard_arrow_down, color: Colors.green);
    }
  }
}
```

### Feedback Collection Dialog

```dart
class FeedbackDialog extends StatefulWidget {
  final String analysisId;
  final double reportedConfidence;
  final Function(AnalysisFeedback) onSubmit;

  const FeedbackDialog({
    required this.analysisId,
    required this.reportedConfidence,
    required this.onSubmit,
  });

  @override
  _FeedbackDialogState createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  AccuracyRating _accuracyRating = AccuracyRating.good;
  double _actualConfidence = 0.7;
  String _comments = '';
  List<String> _issues = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate Analysis Quality'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<AccuracyRating>(
            value: _accuracyRating,
            items: AccuracyRating.values.map((rating) => 
              DropdownMenuItem(
                value: rating,
                child: Text(rating.name),
              )
            ).toList(),
            onChanged: (value) => setState(() => _accuracyRating = value!),
            decoration: const InputDecoration(labelText: 'Accuracy Rating'),
          ),
          Slider(
            value: _actualConfidence,
            onChanged: (value) => setState(() => _actualConfidence = value),
            label: '${(_actualConfidence * 100).toInt()}%',
            divisions: 10,
          ),
          TextField(
            onChanged: (value) => _comments = value,
            decoration: const InputDecoration(labelText: 'Comments'),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitFeedback,
          child: const Text('Submit'),
        ),
      ],
    );
  }

  void _submitFeedback() {
    final feedback = _accuracyRating == AccuracyRating.excellent ||
                    _accuracyRating == AccuracyRating.veryGood
        ? AnalysisFeedback.createPositive(
            analysisId: widget.analysisId,
            accuracyRating: _accuracyRating,
            reportedConfidence: widget.reportedConfidence,
            actualConfidence: _actualConfidence,
            comments: _comments.isNotEmpty ? _comments : null,
          )
        : AnalysisFeedback.createNegative(
            analysisId: widget.analysisId,
            accuracyRating: _accuracyRating,
            reportedIssues: _issues,
            reportedConfidence: widget.reportedConfidence,
            actualConfidence: _actualConfidence,
            comments: _comments.isNotEmpty ? _comments : null,
          );

    widget.onSubmit(feedback);
    Navigator.pop(context);
  }
}
```

## State Management Integration (Riverpod)

### Analysis State Provider

```dart
@riverpod
class AnalysisNotifier extends _$AnalysisNotifier {
  @override
  EnhancedAnalysisRecord? build() => null;

  Future<void> startAnalysis(String refPath, String partPath) async {
    state = EnhancedAnalysisRecord.createNew(
      referenceImagePath: refPath,
      partImagePath: partPath,
      userId: ref.read(userProvider).id,
    );
  }

  Future<void> analyzeQuality() async {
    if (state == null) return;
    
    // Perform quality analysis
    final refQuality = await ref.read(imageAnalysisProvider)
        .analyzeQuality(state!.inputData.referenceImagePath);
    final partQuality = await ref.read(imageAnalysisProvider)
        .analyzeQuality(state!.inputData.partImagePath);

    state = state!.withQualityAnalysis(
      referenceQuality: refQuality,
      partQuality: partQuality,
    );
  }

  Future<void> calculateConfidence(AnalysisComplexity complexity) async {
    if (state?.referenceImageQuality == null) return;

    final confidence = EnhancedConfidenceScore.calculate(
      referenceQuality: state!.referenceImageQuality!,
      partQuality: state!.partImageQuality!,
      complexity: complexity,
      history: await ref.read(performanceHistoryProvider.future),
      contextualData: ref.read(contextualDataProvider),
    );

    final recommendation = ActionRecommendation.generateRecommendations(
      referenceQuality: state!.referenceImageQuality!,
      partQuality: state!.partImageQuality!,
      confidenceScore: confidence,
      issues: state!.referenceImageQuality!.getQualityIssues(),
    );

    state = state!.withConfidenceScore(
      confidence: confidence,
      actionRecommendation: recommendation,
    );
  }

  void submitFeedback(AnalysisFeedback feedback) {
    if (state == null) return;
    state = state!.withUserFeedback(feedback);
  }
}
```

### UI Consumer Widget

```dart
class AnalysisScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(analysisNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quality Analysis')),
      body: analysis == null
          ? const Center(child: Text('No analysis in progress'))
          : Column(
              children: [
                if (analysis.confidenceScore != null)
                  ConfidenceDisplay(confidence: analysis.confidenceScore!),
                if (analysis.recommendation != null)
                  RecommendationCard(
                    recommendation: analysis.recommendation!,
                    onFollow: () => _followRecommendation(ref),
                  ),
                if (analysis.isCompleted)
                  ElevatedButton(
                    onPressed: () => _showFeedbackDialog(context, ref, analysis),
                    child: const Text('Provide Feedback'),
                  ),
              ],
            ),
    );
  }

  void _followRecommendation(WidgetRef ref) {
    ref.read(analysisNotifierProvider.notifier).followRecommendation();
  }

  void _showFeedbackDialog(BuildContext context, WidgetRef ref, EnhancedAnalysisRecord analysis) {
    showDialog(
      context: context,
      builder: (context) => FeedbackDialog(
        analysisId: analysis.id,
        reportedConfidence: analysis.confidenceScore?.overallConfidence ?? 0.0,
        onSubmit: (feedback) {
          ref.read(analysisNotifierProvider.notifier).submitFeedback(feedback);
        },
      ),
    );
  }
}
```

## Data Persistence

### SQLite Database Schema

```sql
-- Analysis Records
CREATE TABLE analysis_records (
  id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  completed_at INTEGER,
  status TEXT NOT NULL,
  input_data TEXT NOT NULL, -- JSON
  confidence_score TEXT,    -- JSON
  recommendation TEXT,      -- JSON
  analysis_result TEXT,     -- JSON
  user_feedback TEXT,       -- JSON
  metadata TEXT NOT NULL    -- JSON
);

-- Performance History
CREATE TABLE performance_history (
  user_id TEXT PRIMARY KEY,
  total_analyses INTEGER DEFAULT 0,
  successful_analyses INTEGER DEFAULT 0,
  recent_accuracy REAL DEFAULT 0.0,
  last_updated INTEGER NOT NULL
);

-- Quality Issues (for analytics)
CREATE TABLE quality_issues (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  analysis_id TEXT NOT NULL,
  issue_type TEXT NOT NULL,
  severity TEXT NOT NULL,
  description TEXT NOT NULL,
  FOREIGN KEY (analysis_id) REFERENCES analysis_records(id)
);
```

### Database Service

```dart
class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<void> saveAnalysisRecord(EnhancedAnalysisRecord record) async {
    final db = await database;
    await db.insert('analysis_records', {
      'id': record.id,
      'created_at': record.createdAt.millisecondsSinceEpoch,
      'completed_at': record.completedAt?.millisecondsSinceEpoch,
      'status': record.status.name,
      'input_data': jsonEncode(record.inputData.toJson()),
      'confidence_score': record.confidenceScore != null 
          ? jsonEncode(record.confidenceScore!.toJson()) : null,
      'recommendation': record.recommendation != null 
          ? jsonEncode(record.recommendation!.toJson()) : null,
      'analysis_result': record.analysisResult != null 
          ? jsonEncode(record.analysisResult!.toJson()) : null,
      'user_feedback': record.userFeedback != null 
          ? jsonEncode(record.userFeedback!.toJson()) : null,
      'metadata': jsonEncode(record.metadata.toJson()),
    });
  }

  Future<List<EnhancedAnalysisRecord>> getAnalysisHistory() async {
    final db = await database;
    final maps = await db.query('analysis_records', 
        orderBy: 'created_at DESC');
    
    return maps.map((map) => EnhancedAnalysisRecord.fromJson({
      'id': map['id'],
      'createdAt': DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      'completedAt': map['completed_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int) 
          : null,
      'status': map['status'],
      'inputData': jsonDecode(map['input_data'] as String),
      'confidenceScore': map['confidence_score'] != null 
          ? jsonDecode(map['confidence_score'] as String) : null,
      'recommendation': map['recommendation'] != null 
          ? jsonDecode(map['recommendation'] as String) : null,
      'analysisResult': map['analysis_result'] != null 
          ? jsonDecode(map['analysis_result'] as String) : null,
      'userFeedback': map['user_feedback'] != null 
          ? jsonDecode(map['user_feedback'] as String) : null,
      'metadata': jsonDecode(map['metadata'] as String),
    })).toList();
  }
}
```

## Testing Integration

All models include comprehensive test coverage. Run tests with:

```bash
flutter test test/enhanced_confidence_system_test.dart
```

## Best Practices

### 1. Always Check Confidence Before Proceeding
```dart
if (confidence.isReliableForDecisionMaking) {
  // Proceed with automated analysis
} else if (confidence.requiresHumanReview) {
  // Request human validation
} else {
  // Show warnings but allow user choice
}
```

### 2. Follow Recommendations When Confidence is Low
```dart
if (confidence.shouldShowWarnings && recommendation.isActionable) {
  // Show recommendation card
  // Allow user to follow steps
  // Recalculate confidence after improvements
}
```

### 3. Collect Feedback for Continuous Improvement
```dart
// Always collect feedback for completed analyses
final feedback = await showFeedbackDialog();
analysisRecord = analysisRecord.withUserFeedback(feedback);

// Use learning weights for model improvement
final weight = feedback.learningWeight;
await trainingService.updateModel(feedback, weight);
```

### 4. Track Performance Metrics
```dart
// Update performance history after each analysis
final history = ModelPerformanceHistory(
  totalAnalyses: totalCount + 1,
  successfulAnalyses: successCount + (wasSuccessful ? 1 : 0),
  recentAccuracy: calculateRecentAccuracy(),
  lastUpdated: DateTime.now(),
);
```

## Error Handling

### Graceful Degradation
```dart
try {
  final confidence = EnhancedConfidenceScore.calculate(
    // ... parameters
  );
} catch (e) {
  // Fallback to basic confidence
  final confidence = EnhancedConfidenceScore(
    imageQualityScore: 0.5,
    modelReliabilityScore: 0.5,
    contextualScore: 0.5,
    historicalScore: 0.5,
    complexityPenalty: 0.2,
    overallConfidence: 0.4,
    factors: [],
  );
}
```

### Validation
```dart
assert(confidence.overallConfidence >= 0.0 && confidence.overallConfidence <= 1.0);
assert(recommendation.steps.isNotEmpty || !recommendation.isActionable);
assert(feedback.confidenceValidation.deviation >= 0.0);
```

This integration guide provides everything needed to successfully implement the Enhanced Confidence System in your Flutter Quality Control Mobile Application.