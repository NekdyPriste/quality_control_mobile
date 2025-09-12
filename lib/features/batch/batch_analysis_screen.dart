import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/batch_analysis.dart';
import '../../core/models/quality_report.dart';
import '../../core/services/batch_analysis_service.dart';
import '../../core/services/background_batch_service.dart';

class BatchAnalysisScreen extends ConsumerStatefulWidget {
  const BatchAnalysisScreen({super.key});

  @override
  ConsumerState<BatchAnalysisScreen> createState() => _BatchAnalysisScreenState();
}

class _BatchAnalysisScreenState extends ConsumerState<BatchAnalysisScreen> {
  final _batchNameController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final List<BatchPhotoPair> _photoPairs = [];
  final ImagePicker _picker = ImagePicker();
  
  bool _isProcessing = false;
  BatchAnalysisJob? _currentJob;
  String _operatorName = '';
  String _productionLine = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _operatorName = prefs.getString('operator_name') ?? 'Operátor QC';
      _productionLine = prefs.getString('production_line') ?? 'Linka A';
    });
  }

  Future<void> _addPhotoPair() async {
    try {
      // Nejprve referenční obrázek
      final referenceImage = await _picker.pickImage(source: ImageSource.camera);
      if (referenceImage == null) return;

      // Dialog pro zadání typu dílu
      final partType = await _showPartTypeDialog();
      if (partType == null) return;

      // Seriové číslo dílu (volitelné)
      final partSerial = await _showPartSerialDialog();

      // Potom obrázek dílu
      final partImage = await _picker.pickImage(source: ImageSource.camera);
      if (partImage == null) return;

      final photoPair = BatchPhotoPair(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        referenceImagePath: referenceImage.path,
        partImagePath: partImage.path,
        partType: partType,
        partSerial: partSerial,
      );

      setState(() {
        _photoPairs.add(photoPair);
      });

      _showSuccess('Pár fotografií přidán (${_photoPairs.length})');
    } catch (e) {
      _showError('Chyba při přidávání fotografií: $e');
    }
  }

  Future<PartType?> _showPartTypeDialog() async {
    return await showDialog<PartType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Typ dílu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Výlisky'),
              leading: const Icon(Icons.build),
              onTap: () => Navigator.pop(context, PartType.vylisky),
            ),
            ListTile(
              title: const Text('Obráběné díly'),
              leading: const Icon(Icons.precision_manufacturing),
              onTap: () => Navigator.pop(context, PartType.obrabene),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showPartSerialDialog() async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seriové číslo dílu'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Zadejte seriové číslo (volitelné)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Přeskočit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _startBatchAnalysis() async {
    if (_photoPairs.isEmpty) {
      _showError('Přidejte alespoň jeden pár fotografií');
      return;
    }

    if (_batchNameController.text.trim().isEmpty) {
      _showError('Zadejte název batch úlohy');
      return;
    }

    // Dialog pro volbu typu zpracování
    final runInBackground = await _showProcessingTypeDialog();
    if (runInBackground == null) return;

    setState(() => _isProcessing = true);

    try {
      if (runInBackground) {
        // Background zpracování
        await _startBackgroundBatchAnalysis();
      } else {
        // Foreground zpracování (původní kód)
        await _startForegroundBatchAnalysis();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Chyba při spuštění batch analýzy: $e');
    }
  }

  Future<bool?> _showProcessingTypeDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Typ zpracování'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jak chcete zpracovat batch analýzu?'),
            SizedBox(height: 16),
            Text('• Foreground: Aplikace musí zůstat otevřená'),
            Text('• Background: Pokračuje i po zavření aplikace'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Foreground'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Background'),
          ),
        ],
      ),
    );
  }

  Future<void> _startBackgroundBatchAnalysis() async {
    final jobId = DateTime.now().millisecondsSinceEpoch.toString();
    
    await BackgroundBatchService.scheduleBatchAnalysis(
      jobId: jobId,
      photoPairs: _photoPairs,
      jobData: {
        'name': _batchNameController.text.trim(),
        'operatorName': _operatorName,
        'productionLine': _productionLine,
        'batchNumber': _batchNumberController.text.trim(),
      },
    );

    setState(() => _isProcessing = false);
    
    _showSuccess('Batch analýza naplánována na pozadí. Pokračuje i po zavření aplikace.');
    Navigator.pop(context);
  }

  Future<void> _startForegroundBatchAnalysis() async {
    final batchService = ref.read(batchAnalysisServiceProvider);
    
    final job = await batchService.createBatchJob(
      name: _batchNameController.text.trim(),
      photoPairs: _photoPairs,
      operatorName: _operatorName,
      productionLine: _productionLine,
      batchNumber: _batchNumberController.text.trim(),
    );

    setState(() => _currentJob = job);

    // Poslouchej aktualizace
    batchService.jobUpdates.listen((updatedJob) {
      if (updatedJob.id == job.id) {
        setState(() => _currentJob = updatedJob);
        
        if (updatedJob.status == BatchStatus.completed) {
          setState(() => _isProcessing = false);
          _showBatchResults(updatedJob);
        } else if (updatedJob.status == BatchStatus.failed) {
          setState(() => _isProcessing = false);
          _showError('Batch analýza selhala');
        }
      }
    });

    // Spustit analýzu
    await batchService.startBatchAnalysis(job.id);
  }

  void _showBatchResults(BatchAnalysisJob job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batch analýza dokončena'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Celkem dílů: ${job.totalPairs}'),
            Text('Dokončeno: ${job.completedPairs}'),
            Text('Selhalo: ${job.failedPairs}'),
            const SizedBox(height: 16),
            Text('PASS: ${job.passCount}', style: const TextStyle(color: Colors.green)),
            Text('FAIL: ${job.failCount}', style: const TextStyle(color: Colors.red)),
            Text('WARNING: ${job.warningCount}', style: const TextStyle(color: Colors.orange)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendReport(job);
            },
            child: const Text('Odeslat report'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReport(BatchAnalysisJob job) async {
    final prefs = await SharedPreferences.getInstance();
    final defaultEmail = prefs.getString('default_email') ?? '';
    
    final emailController = TextEditingController(text: defaultEmail);
    
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odeslat report'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email adresa',
            hintText: 'kvalita@firma.cz',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, emailController.text.trim()),
            child: const Text('Odeslat'),
          ),
        ],
      ),
    );

    if (email != null && email.isNotEmpty) {
      try {
        final batchService = ref.read(batchAnalysisServiceProvider);
        await batchService.sendBatchReport(job.id, email);
        _showSuccess('Report odeslán na $email');
      } catch (e) {
        _showError('Chyba při odesílání reportu: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch analýza'),
        backgroundColor: Colors.purple.withOpacity(0.1),
      ),
      body: _isProcessing && _currentJob != null
          ? _buildProgressView(_currentJob!)
          : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildJobInfoCard(),
          const SizedBox(height: 16),
          _buildPhotoPairsCard(),
          const SizedBox(height: 24),
          if (_photoPairs.isNotEmpty) _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildJobInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.batch_prediction, color: Colors.purple),
                SizedBox(width: 8),
                Text('Informace o úloze', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _batchNameController,
              decoration: const InputDecoration(
                labelText: 'Název batch úlohy',
                hintText: 'Kontrola série A001',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _batchNumberController,
              decoration: const InputDecoration(
                labelText: 'Číslo série/batch (volitelné)',
                hintText: 'B2024-001',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Operátor: $_operatorName'),
                ),
                Expanded(
                  child: Text('Linka: $_productionLine'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPairsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Páry fotografií (${_photoPairs.length})', 
                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addPhotoPair,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Přidat pár'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_photoPairs.isEmpty)
              const Text('Zatím žádné fotografie. Přidejte páry referenční + díl.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _photoPairs.length,
                itemBuilder: (context, index) {
                  final pair = _photoPairs[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    title: Text('${pair.partType.name.toUpperCase()}'),
                    subtitle: Text(pair.partSerial ?? 'Bez sériového čísla'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _photoPairs.removeAt(index);
                        });
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _startBatchAnalysis,
        icon: const Icon(Icons.play_arrow),
        label: Text('Spustit batch analýzu (${_photoPairs.length} párů)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildProgressView(BatchAnalysisJob job) {
    final progress = job.progressPercentage / 100;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics, size: 64, color: Colors.purple),
          const SizedBox(height: 24),
          Text(
            'Zpracovává se: ${job.name}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
          const SizedBox(height: 16),
          Text(
            '${job.completedPairs + job.failedPairs} z ${job.totalPairs} dokončeno',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text('${(progress * 100).toStringAsFixed(1)}%'),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusCard('PASS', job.passCount, Colors.green),
              _buildStatusCard('FAIL', job.failCount, Colors.red),
              _buildStatusCard('WARNING', job.warningCount, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Odhad času: ${(job.totalPairs * 3).toInt()} minut',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String label, int count, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
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

  @override
  void dispose() {
    _batchNameController.dispose();
    _batchNumberController.dispose();
    super.dispose();
  }
}