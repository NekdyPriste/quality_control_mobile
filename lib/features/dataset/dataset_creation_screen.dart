import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../annotation/photo_annotation_screen.dart';
import '../../core/services/annotation_export_service.dart';
import '../../core/models/annotation/error_annotation.dart';

class DatasetCreationScreen extends ConsumerStatefulWidget {
  const DatasetCreationScreen({super.key});

  @override
  ConsumerState<DatasetCreationScreen> createState() => _DatasetCreationScreenState();
}

class _DatasetCreationScreenState extends ConsumerState<DatasetCreationScreen> {
  List<AnnotatedImage> _annotations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingAnnotations();
  }

  Future<void> _loadExistingAnnotations() async {
    try {
      final exportService = ref.read(annotationExportServiceProvider);
      final annotations = await exportService.loadAllAnnotatedImages();
      setState(() {
        _annotations = annotations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při načítání anotací: $e')),
        );
      }
    }
  }

  void _startAnnotation() async {
    try {
      // Use native camera directly - simple and reliable
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (image != null && mounted) {
        final imageFile = File(image.path);

        // Navigate directly to annotation screen
        final result = await Navigator.push<AnnotatedImage>(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoAnnotationScreen(
              imageFile: imageFile,
              partSerialNumber: null,
            ),
          ),
        );

        if (result != null) {
          // Save annotated image
          try {
            final exportService = ref.read(annotationExportServiceProvider);
            await exportService.saveAnnotatedImage(result);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Uloženo: ${result.annotations.length} označených chyb'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );

              // Refresh the list
              _loadExistingAnnotations();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('❌ Chyba při ukládání: $e')),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Chyba při spuštění kamery: $e')),
        );
      }
    }
  }

  Future<void> _exportDataset(ExportFormat format) async {
    if (_annotations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Žádné anotace k exportu')),
      );
      return;
    }

    try {
      final exportService = ref.read(annotationExportServiceProvider);
      final filePath = await exportService.exportDataset(
        images: _annotations,
        format: format,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dataset exportován: ${filePath.split('/').last}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Zobrazit',
              onPressed: () => _showExportDetails(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při exportu: $e')),
        );
      }
    }
  }

  void _showExportDetails(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export dokončen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Soubor: ${filePath.split('/').last}'),
            const SizedBox(height: 8),
            Text('Umístění: $filePath'),
            const SizedBox(height: 8),
            Text('Počet anotovaných obrázků: ${_annotations.length}'),
            Text('Celkový počet označených chyb: ${_annotations.fold(0, (sum, img) => sum + img.annotations.length)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dataset Creation'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Statistics header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF4CAF50), const Color(0xFF4CAF50).withOpacity(0.8)],
              ),
            ),
            child: Column(
              children: [
                Text(
                  '📊 Statistiky datasetu',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard('Obrázky', '${_annotations.length}', Icons.image),
                    _buildStatCard(
                      'Chyby',
                      '${_annotations.fold(0, (sum, img) => sum + img.annotations.length)}',
                      Icons.error_outline
                    ),
                    _buildStatCard(
                      'Kritické',
                      '${_annotations.fold(0, (sum, img) => sum + img.annotations.where((a) => a.severity == ErrorSeverity.critical).length)}',
                      Icons.warning
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Primary action - Create new annotation
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startAnnotation,
                    icon: const Icon(Icons.camera_alt, size: 28),
                    label: const Text(
                      'Přidat novou anotaci',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Export options
                const Text(
                  'Export datasetu:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: _buildExportButton(
                        'COCO',
                        'ML Standard',
                        Icons.code,
                        () => _exportDataset(ExportFormat.cocoFormat),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildExportButton(
                        'YOLO',
                        'YOLO Format',
                        Icons.adjust,
                        () => _exportDataset(ExportFormat.yoloFormat),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildExportButton(
                        'JSON',
                        'Custom Format',
                        Icons.data_object,
                        () => _exportDataset(ExportFormat.json),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildExportButton(
                        'CSV',
                        'Excel Compatible',
                        Icons.table_chart,
                        () => _exportDataset(ExportFormat.csv),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Backup info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ℹ️ Dataset se automaticky zachová při aktualizaci aplikace',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List of annotations
          Expanded(
            child: _annotations.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dataset, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Zatím žádné anotace',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Začněte přidáním první anotace',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _annotations.length,
                    itemBuilder: (context, index) {
                      final annotation = _annotations[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.image, color: Color(0xFF4CAF50)),
                          title: Text('Obrázek ${index + 1}'),
                          subtitle: Text(
                            '${annotation.annotations.length} označených chyb • ${DateTime.fromMillisecondsSinceEpoch(
                              int.tryParse(annotation.imagePath.split('_').last.split('.').first) ?? 0
                            ).toString().split(' ')[0]}',
                          ),
                          trailing: Text(
                            '${annotation.annotations.where((a) => a.severity == ErrorSeverity.critical).length}🔴',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(String title, String subtitle, IconData icon, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}