import 'package:flutter/material.dart';
import '../../core/models/quality/action_recommendation.dart';

class RecommendationScreen extends StatelessWidget {
  final List<ActionRecommendation> recommendations;
  final String analysisResult;

  const RecommendationScreen({
    super.key,
    required this.recommendations,
    required this.analysisResult,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doporučení pro zlepšení'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnalysisOverview(),
            const SizedBox(height: 24),
            ...recommendations.map(_buildRecommendationCard),
            const SizedBox(height: 16),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text('Výsledek analýzy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(analysisResult, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(ActionRecommendation recommendation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getPriorityIcon(recommendation.priority),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(recommendation.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(recommendation.description, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            _buildStepsList(recommendation.steps),
            const SizedBox(height: 12),
            _buildMetadata(recommendation),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsList(List<RecommendationStep> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kroky:', style: TextStyle(fontWeight: FontWeight.bold)),
        ...steps.map((step) => Padding(
          padding: const EdgeInsets.only(left: 16, top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(color: Colors.blue)),
              Expanded(child: Text(step.action)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildMetadata(ActionRecommendation recommendation) {
    return Row(
      children: [
        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text('${recommendation.estimatedTime.inMinutes} min', style: TextStyle(color: Colors.grey[600])),
        const SizedBox(width: 16),
        Icon(Icons.trending_up, size: 16, color: Colors.green[600]),
        const SizedBox(width: 4),
        Text('Zlepšení: ${(recommendation.expectedImprovement.qualityIncrease * 100).toInt()}%',
             style: TextStyle(color: Colors.green[600])),
      ],
    );
  }

  Widget _getPriorityIcon(ActionPriority priority) {
    switch (priority) {
      case ActionPriority.critical:
        return const Icon(Icons.error, color: Colors.red);
      case ActionPriority.high:
        return const Icon(Icons.priority_high, color: Colors.orange);
      case ActionPriority.medium:
        return const Icon(Icons.info, color: Colors.blue);
      case ActionPriority.low:
        return const Icon(Icons.info_outline, color: Colors.grey);
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zpět k výsledkům'),
          ),
        ),
      ],
    );
  }
}