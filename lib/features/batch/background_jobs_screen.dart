import 'package:flutter/material.dart';
import '../../core/models/batch_analysis.dart';
import '../../core/services/background_batch_service.dart';

class BackgroundJobsScreen extends StatefulWidget {
  const BackgroundJobsScreen({super.key});

  @override
  State<BackgroundJobsScreen> createState() => _BackgroundJobsScreenState();
}

class _BackgroundJobsScreenState extends State<BackgroundJobsScreen> {
  List<BatchAnalysisJob> _jobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    try {
      final jobs = await BackgroundBatchService.getBackgroundJobs();
      setState(() {
        _jobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Chyba při načítání úloh: $e');
    }
  }

  Future<void> _cancelJob(BatchAnalysisJob job) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zrušit úlohu'),
        content: Text('Opravdu chcete zrušit úlohu "${job.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ne'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Zrušit úlohu'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await BackgroundBatchService.cancelBatchAnalysis(job.id);
        _loadJobs(); // Reload jobs
        _showSuccess('Úloha "${job.name}" byla zrušena');
      } catch (e) {
        _showError('Chyba při rušení úlohy: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background úlohy'),
        backgroundColor: Colors.green.withOpacity(0.1),
        actions: [
          IconButton(
            onPressed: _loadJobs,
            icon: const Icon(Icons.refresh),
            tooltip: 'Obnovit',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Žádné background úlohy',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadJobs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _jobs.length,
                    itemBuilder: (context, index) {
                      final job = _jobs[index];
                      return _buildJobCard(job);
                    },
                  ),
                ),
    );
  }

  Widget _buildJobCard(BatchAnalysisJob job) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(job.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getStatusText(job.status),
                        style: TextStyle(
                          color: _getStatusColor(job.status),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (job.status == BatchStatus.processing || job.status == BatchStatus.pending)
                  IconButton(
                    onPressed: () => _cancelJob(job),
                    icon: const Icon(Icons.cancel),
                    color: Colors.red,
                    tooltip: 'Zrušit úlohu',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(Icons.photo_library, '${job.totalPairs} párů'),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.schedule, _formatDate(job.createdAt)),
              ],
            ),
            if (job.operatorName != null || job.productionLine != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (job.operatorName != null)
                    _buildInfoChip(Icons.person, job.operatorName!),
                  const SizedBox(width: 8),
                  if (job.productionLine != null)
                    _buildInfoChip(Icons.factory, job.productionLine!),
                ],
              ),
            ],
            if (job.status == BatchStatus.completed) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildResultChip('PASS', job.passCount, Colors.green),
                  _buildResultChip('FAIL', job.failCount, Colors.red),
                  _buildResultChip('WARNING', job.warningCount, Colors.orange),
                ],
              ),
            ],
            if (job.status == BatchStatus.processing) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: job.progressPercentage / 100,
                backgroundColor: Colors.grey.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              const SizedBox(height: 8),
              Text(
                '${job.completedPairs}/${job.totalPairs} dokončeno (${job.progressPercentage.toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BatchStatus status) {
    switch (status) {
      case BatchStatus.pending:
        return const Icon(Icons.schedule, color: Colors.blue, size: 32);
      case BatchStatus.processing:
        return const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        );
      case BatchStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 32);
      case BatchStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 32);
    }
  }

  String _getStatusText(BatchStatus status) {
    switch (status) {
      case BatchStatus.pending:
        return 'Naplánováno';
      case BatchStatus.processing:
        return 'Zpracovává se';
      case BatchStatus.completed:
        return 'Dokončeno';
      case BatchStatus.failed:
        return 'Selhalo';
    }
  }

  Color _getStatusColor(BatchStatus status) {
    switch (status) {
      case BatchStatus.pending:
        return Colors.blue;
      case BatchStatus.processing:
        return Colors.orange;
      case BatchStatus.completed:
        return Colors.green;
      case BatchStatus.failed:
        return Colors.red;
    }
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildResultChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}