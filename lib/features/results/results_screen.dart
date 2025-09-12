import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/quality_report.dart';
import '../../core/models/comparison_result.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/email_service.dart';
import '../../core/services/dataset_export_service.dart';
import 'widgets/defect_overlay_widget.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final PartType partType;
  final String referenceImagePath;
  final String partImagePath;
  final ComparisonResult comparisonResult;

  const ResultsScreen({
    super.key,
    required this.partType,
    required this.referenceImagePath,
    required this.partImagePath,
    required this.comparisonResult,
  });

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  int? _savedInspectionId;
  bool _isSaving = false;
  bool _isEmailSending = false;

  @override
  void initState() {
    super.initState();
    _autoSaveInspection();
  }

  Future<void> _autoSaveInspection() async {
    setState(() => _isSaving = true);
    
    try {
      final dbHelper = DatabaseHelper();
      final inspectionId = await dbHelper.saveInspection(
        referenceImagePath: widget.referenceImagePath,
        partImagePath: widget.partImagePath,
        partType: widget.partType,
        comparisonResult: widget.comparisonResult,
        operatorName: 'Demo Operator', // V produkci by se zadávalo
        productionLine: 'Linka A',
        batchNumber: 'BATCH_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      setState(() {
        _savedInspectionId = inspectionId;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Inspekce uložena (ID: $inspectionId)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Chyba při ukládání: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImageWidget(String imagePath, {required String fallbackText, required IconData fallbackIcon}) {
    if (imagePath.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(fallbackIcon, size: 40, color: Colors.grey),
              Text(fallbackText, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    // Pro web vždy zobrazíme placeholder s informací
    if (kIsWeb) {
      if (imagePath.startsWith('blob:') || imagePath.startsWith('data:')) {
        return Image.network(
          imagePath,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 40, color: Colors.red),
                    Text('Chyba načítání\nobrázku', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        // Pro web zobrazíme placeholder s informací o cestě
        return Container(
          color: Colors.blue[50],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(fallbackIcon, size: 40, color: Colors.blue),
                Text(fallbackText, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Web: ${imagePath.split('/').last}', 
                     style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      }
    }

    // Pro mobil používáme Image.file - tento kód se nevykoná na webu
    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 40, color: Colors.red),
                Text('Chyba načítání\nobrázku', textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Výsledky kontroly'),
        backgroundColor: _getStatusColor().withOpacity(0.2),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'email',
                child: Row(
                  children: [
                    Icon(Icons.email),
                    SizedBox(width: 8),
                    Text('Odeslat email'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export datasetu'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Sdílet report'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildSummaryCard(),
            const SizedBox(height: 16),
            _buildImagesCard(),
            const SizedBox(height: 16),
            if (widget.comparisonResult.hasDefects) _buildDefectsCard(),
            const SizedBox(height: 16),
            _buildActionsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = widget.comparisonResult.overallQuality;
    final color = _getStatusColor();
    
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(_getStatusIcon(), size: 48, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Spolehlivost: ${(widget.comparisonResult.confidenceScore * 100).round()}%',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shrnutí',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildFormattedSummary(widget.comparisonResult.summary),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Celkem defektů', '${widget.comparisonResult.defectsFound.length}'),
                _buildStatItem('Kritické', '${widget.comparisonResult.criticalDefects}'),
                _buildStatItem('Závažné', '${widget.comparisonResult.majorDefects}'),
                _buildStatItem('Menší', '${widget.comparisonResult.minorDefects}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildImagesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Porovnání obrázků',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Referenční', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildImageWidget(
                            widget.referenceImagePath,
                            fallbackText: 'Referenční\nobrázek',
                            fallbackIcon: Icons.image,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Kontrolovaný díl', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildImageWidget(
                            widget.partImagePath,
                            fallbackText: 'Kontrolovaný\ndíl',
                            fallbackIcon: Icons.precision_manufacturing,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefectsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Zjištěné defekty',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (widget.comparisonResult.hasDefects)
                  ElevatedButton.icon(
                    onPressed: _showDefectOverlay,
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Zobrazit na obrázku'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...widget.comparisonResult.defectsFound.map((defect) => _buildDefectItem(defect)),
          ],
        ),
      ),
    );
  }

  Widget _buildDefectItem(defect) {
    Color severityColor;
    IconData severityIcon;
    
    switch (defect.severity.toString()) {
      case 'DefectSeverity.critical':
        severityColor = Colors.red;
        severityIcon = Icons.error;
        break;
      case 'DefectSeverity.major':
        severityColor = Colors.orange;
        severityIcon = Icons.warning;
        break;
      default:
        severityColor = Colors.yellow[700]!;
        severityIcon = Icons.info;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(severityIcon, color: severityColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  defect.description,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Spolehlivost: ${(defect.confidence * 100).round()}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Akce',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isEmailSending ? null : () => _sendEmail(context),
                  icon: _isEmailSending 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.email),
                  label: Text(_isEmailSending ? 'Odesílám...' : 'Odeslat email'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                  icon: const Icon(Icons.home),
                  label: const Text('Domů'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _newInspection(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Nová kontrola'),
                ),
              ],
            ),
            if (_savedInspectionId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Inspekce ID $_savedInspectionId uložena do databáze pro trénování AI modelu',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.comparisonResult.overallQuality) {
      case QualityStatus.pass:
        return Colors.green;
      case QualityStatus.fail:
        return Colors.red;
      case QualityStatus.warning:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.comparisonResult.overallQuality) {
      case QualityStatus.pass:
        return Icons.check_circle;
      case QualityStatus.fail:
        return Icons.cancel;
      case QualityStatus.warning:
        return Icons.warning;
    }
  }

  String _getStatusText() {
    switch (widget.comparisonResult.overallQuality) {
      case QualityStatus.pass:
        return 'VYHOVUJE';
      case QualityStatus.fail:
        return 'NEVYHOVUJE';
      case QualityStatus.warning:
        return 'UPOZORNĚNÍ';
    }
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'email':
        await _sendEmail(context);
        break;
      case 'export':
        await _exportDataset();
        break;
      case 'share':
        await _shareReport();
        break;
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    if (_savedInspectionId == null) return;

    // Zobrazení dialogu pro zadání emailu
    final emailController = TextEditingController(text: 'kvalita@firma.cz');
    
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odeslat email report'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email adresa',
            hintText: 'zadejte@email.cz',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, emailController.text),
            child: const Text('Odeslat'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    setState(() => _isEmailSending = true);

    try {
      final emailService = ref.read(emailServiceProvider);
      final success = await emailService.sendQualityReport(
        inspectionId: _savedInspectionId!,
        recipientEmail: email,
        partType: widget.partType,
        comparisonResult: widget.comparisonResult,
        operatorName: 'Demo Operator',
        productionLine: 'Linka A',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? '✅ Email odeslán na $email' 
                : '❌ Chyba při odesílání emailu'
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Chyba: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isEmailSending = false);
    }
  }

  Future<void> _exportDataset() async {
    try {
      final exportService = ref.read(datasetExportServiceProvider);
      
      // Zobrazení dialogu pro výběr formátu
      final format = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export datasetu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('JSONL (Gemini fine-tuning)'),
                subtitle: const Text('Pro trénování AI modelu'),
                onTap: () => Navigator.pop(context, 'jsonl'),
              ),
              ListTile(
                title: const Text('JSON (kompletní data)'),
                subtitle: const Text('Strukturovaná data s metadaty'),
                onTap: () => Navigator.pop(context, 'json'),
              ),
              ListTile(
                title: const Text('CSV (analýzy)'),
                subtitle: const Text('Pro Excel a datové analýzy'),
                onTap: () => Navigator.pop(context, 'csv'),
              ),
            ],
          ),
        ),
      );

      if (format == null) return;

      final filePath = await exportService.exportTrainingDataset(
        partType: widget.partType,
        format: format,
        limit: 1000,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Dataset exportován: $filePath'),
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

  Future<void> _shareReport() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📤 Share funkce bude implementována (PDF, obrázek)'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _newInspection(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _showDefectOverlay() {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text(
              'Defekty na obrázku',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Kliknutím na číslo zobrazíte detail defektu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                        maxWidth: MediaQuery.of(context).size.width * 0.9,
                      ),
                      child: DefectOverlayWidget(
                        imagePath: widget.partImagePath,
                        comparisonResult: widget.comparisonResult,
                        imageHeight: 400,
                        imageWidth: MediaQuery.of(context).size.width * 0.9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedSummary(String summary) {
    // Rozdělíme text na řádky a vytvoříme strukturované zobrazení
    final lines = summary.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          final trimmedLine = line.trim();
          
          // Detekce nadpisů (obsahují velká písmena a dvojtečku)
          if (_isHeading(trimmedLine)) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                trimmedLine,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            );
          }
          
          // Detekce seznamu (začíná s •, -, nebo číslicí)
          if (_isListItem(trimmedLine)) {
            return Padding(
              padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _cleanListItem(trimmedLine),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Detekce závěru/výsledku (obsahuje klíčová slova)
          if (_isConclusion(trimmedLine)) {
            return Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getConclusionColor(trimmedLine).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _getConclusionColor(trimmedLine).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getConclusionIcon(trimmedLine),
                    color: _getConclusionColor(trimmedLine),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trimmedLine,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _getConclusionColor(trimmedLine),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Obyčejný text s odstavcem
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              trimmedLine,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isHeading(String line) {
    // Nadpisy obsahují velká písmena a často končí dvojtečkou
    return line.contains(':') && 
           line.toUpperCase() == line &&
           line.length > 3 &&
           line.length < 50;
  }

  bool _isListItem(String line) {
    // Řádky seznamu začínají s •, -, číslem s tečkou, nebo obsahují "chybí", "přebývá"
    return line.startsWith('•') ||
           line.startsWith('-') ||
           line.startsWith('*') ||
           RegExp(r'^\d+\.').hasMatch(line) ||
           line.toLowerCase().contains('chybí') ||
           line.toLowerCase().contains('přebývá') ||
           line.toLowerCase().contains('defekt') ||
           line.toLowerCase().contains('problém');
  }

  String _cleanListItem(String line) {
    // Odstraníme úvodní znaky seznamu
    return line
        .replaceFirst(RegExp(r'^[•\-*]\s*'), '')
        .replaceFirst(RegExp(r'^\d+\.\s*'), '');
  }

  bool _isConclusion(String line) {
    // Závěrečné věty obsahující výsledek kontroly
    final lowerLine = line.toLowerCase();
    return lowerLine.contains('vyhovuje') ||
           lowerLine.contains('nevyhovuje') ||
           lowerLine.contains('doporučen') ||
           lowerLine.contains('závěr') ||
           lowerLine.contains('výsledek') ||
           lowerLine.contains('hodnocení');
  }

  Color _getConclusionColor(String line) {
    final lowerLine = line.toLowerCase();
    if (lowerLine.contains('vyhovuje') && !lowerLine.contains('nevyhovuje')) {
      return Colors.green;
    } else if (lowerLine.contains('nevyhovuje')) {
      return Colors.red;
    } else if (lowerLine.contains('upozornění') || lowerLine.contains('pozor')) {
      return Colors.orange;
    }
    return Colors.blue;
  }

  IconData _getConclusionIcon(String line) {
    final lowerLine = line.toLowerCase();
    if (lowerLine.contains('vyhovuje') && !lowerLine.contains('nevyhovuje')) {
      return Icons.check_circle;
    } else if (lowerLine.contains('nevyhovuje')) {
      return Icons.error;
    } else if (lowerLine.contains('upozornění') || lowerLine.contains('pozor')) {
      return Icons.warning;
    }
    return Icons.info;
  }
}