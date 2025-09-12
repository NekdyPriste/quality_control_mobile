import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/quality_report.dart';
import '../../core/models/comparison_result.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/dataset_export_service.dart';

class InspectionHistoryScreen extends ConsumerStatefulWidget {
  const InspectionHistoryScreen({super.key});

  @override
  ConsumerState<InspectionHistoryScreen> createState() => _InspectionHistoryScreenState();
}

class _InspectionHistoryScreenState extends ConsumerState<InspectionHistoryScreen> {
  List<QualityReport> _inspections = [];
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  String _selectedFilter = 'ALL';
  
  @override
  void initState() {
    super.initState();
    _loadInspections();
  }

  Future<void> _loadInspections() async {
    setState(() => _isLoading = true);
    
    try {
      final dbHelper = DatabaseHelper();
      final inspections = await dbHelper.getAllInspections(limit: 100);
      final stats = await dbHelper.getStatistics();
      
      setState(() {
        _inspections = inspections;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při načítání: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<QualityReport> get _filteredInspections {
    switch (_selectedFilter) {
      case 'PASS':
        return _inspections.where((i) => i.comparisonResult.overallQuality == QualityStatus.pass).toList();
      case 'FAIL':
        return _inspections.where((i) => i.comparisonResult.overallQuality == QualityStatus.fail).toList();
      case 'WARNING':
        return _inspections.where((i) => i.comparisonResult.overallQuality == QualityStatus.warning).toList();
      default:
        return _inspections;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historie kontrol'),
        backgroundColor: Colors.indigo.withOpacity(0.1),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_all',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export všech dat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.analytics),
                    SizedBox(width: 8),
                    Text('Statistiky'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Obnovit'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatisticsCard(),
                _buildFilterRow(),
                Expanded(child: _buildInspectionsList()),
              ],
            ),
    );
  }

  Widget _buildStatisticsCard() {
    if (_statistics == null) return const SizedBox.shrink();

    final totalInspections = _statistics!['total_inspections'] as int;
    final passRate = _statistics!['pass_rate'] as double;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[50]!, Colors.blue[50]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.indigo),
              const SizedBox(width: 8),
              const Text(
                'Přehled statistik',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Celkem kontrol',
                totalInspections.toString(),
                Icons.assignment,
                Colors.blue,
              ),
              _buildStatItem(
                'Úspěšnost',
                '${passRate.toStringAsFixed(1)}%',
                Icons.check_circle,
                passRate > 80 ? Colors.green : Colors.orange,
              ),
              _buildStatItem(
                'Defektní',
                '${_statistics!['fail_count']}',
                Icons.error,
                Colors.red,
              ),
              _buildStatItem(
                'Varování',
                '${_statistics!['warning_count']}',
                Icons.warning,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('Filtr: '),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'Vše'),
                  _buildFilterChip('PASS', 'Vyhovuje'),
                  _buildFilterChip('FAIL', 'Nevyhovuje'),
                  _buildFilterChip('WARNING', 'Upozornění'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
      ),
    );
  }

  Widget _buildInspectionsList() {
    final filteredInspections = _filteredInspections;
    
    if (filteredInspections.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Žádné inspekce nenalezeny',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredInspections.length,
      itemBuilder: (context, index) {
        final inspection = filteredInspections[index];
        return _buildInspectionCard(inspection);
      },
    );
  }

  Widget _buildInspectionCard(QualityReport report) {
    final result = report.comparisonResult;
    final statusColor = _getStatusColor(result.overallQuality);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showInspectionDetail(report),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      report.statusDisplayName,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'ID: ${report.id}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.precision_manufacturing,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    report.partTypeDisplayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    _formatDateTime(report.createdAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.speed,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text('Spolehlivost: ${(result.confidenceScore * 100).round()}%'),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.bug_report,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text('Defekty: ${result.defectsFound.length}'),
                ],
              ),
              if (result.hasDefects) ...[
                const SizedBox(height: 8),
                Text(
                  result.summary.length > 100 
                      ? '${result.summary.substring(0, 100)}...'
                      : result.summary,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (result.criticalDefects > 0)
                    _buildDefectBadge('${result.criticalDefects} kritické', Colors.red),
                  if (result.majorDefects > 0) ...[
                    const SizedBox(width: 4),
                    _buildDefectBadge('${result.majorDefects} závažné', Colors.orange),
                  ],
                  if (result.minorDefects > 0) ...[
                    const SizedBox(width: 4),
                    _buildDefectBadge('${result.minorDefects} menší', Colors.yellow[700]!),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefectBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10),
      ),
    );
  }

  Color _getStatusColor(QualityStatus status) {
    switch (status) {
      case QualityStatus.pass:
        return Colors.green;
      case QualityStatus.fail:
        return Colors.red;
      case QualityStatus.warning:
        return Colors.orange;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showInspectionDetail(QualityReport report) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Inspekce ID: ${report.id}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Typ dílu: ${report.partTypeDisplayName}'),
              Text('Datum: ${_formatDateTime(report.createdAt)}'),
              Text('Výsledek: ${report.statusDisplayName}'),
              Text('Spolehlivost: ${(report.comparisonResult.confidenceScore * 100).round()}%'),
              const SizedBox(height: 16),
              if (report.comparisonResult.hasDefects) ...[
                const Text('Defekty:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...report.comparisonResult.defectsFound.map((defect) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• ${defect.description}'),
                )),
              ],
              const SizedBox(height: 16),
              Text('Shrnutí: ${report.comparisonResult.summary}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'export_all':
        await _exportAllData();
        break;
      case 'stats':
        await _showDetailedStats();
        break;
      case 'refresh':
        await _loadInspections();
        break;
    }
  }

  Future<void> _exportAllData() async {
    try {
      final exportService = ref.read(datasetExportServiceProvider);
      
      // Export ve všech formátech
      final jsonlPath = await exportService.exportTrainingDataset(format: 'jsonl');
      final csvPath = await exportService.exportTrainingDataset(format: 'csv');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Data exportována:\n$jsonlPath\n$csvPath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Chyba při exportu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDetailedStats() async {
    if (_statistics == null) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detailní statistiky'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Celkový počet kontrol: ${_statistics!['total_inspections']}'),
              Text('Úspěšné: ${_statistics!['pass_count']}'),
              Text('Neúspěšné: ${_statistics!['fail_count']}'),
              Text('S upozorněním: ${_statistics!['warning_count']}'),
              const SizedBox(height: 16),
              Text('Úspěšnost: ${(_statistics!['pass_rate'] as double).toStringAsFixed(1)}%'),
              const SizedBox(height: 16),
              const Text('Dataset je připraven pro:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('• Trénování specializovaného AI modelu'),
              const Text('• Analýzu trendů kvality'),
              const Text('• Optimalizaci výrobních procesů'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }
}