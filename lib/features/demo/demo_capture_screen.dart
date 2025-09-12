import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/quality_report.dart';
import '../analysis/analysis_screen.dart';

class DemoCaptureScreen extends StatefulWidget {
  final PartType partType;

  const DemoCaptureScreen({
    super.key,
    required this.partType,
  });

  @override
  State<DemoCaptureScreen> createState() => _DemoCaptureScreenState();
}

class _DemoCaptureScreenState extends State<DemoCaptureScreen> {
  String? _referenceImagePath;
  String? _partImagePath;
  bool _isCapturing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('DEMO - ${_getPartTypeDisplayName()}'),
        backgroundColor: Colors.purple.withOpacity(0.2),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science, color: Colors.purple),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'DEMO REŽIM - Simulované obrázky pro testování AI analýzy',
                      style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Icon(
              Icons.photo_library,
              size: 80,
              color: Colors.purple,
            ),
            const SizedBox(height: 20),
            const Text(
              'Demo kontrola kvality',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Typ dílu: ${_getPartTypeDisplayName()}',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            _buildDemoStep(
              stepNumber: 1,
              title: 'Referenční obrázek',
              description: 'Simulovaný 3D model',
              icon: Icons.photo_library,
              color: Colors.blue,
              isCompleted: _referenceImagePath != null,
              onTap: () => _simulateReferenceCapture(),
            ),
            const SizedBox(height: 16),
            _buildDemoStep(
              stepNumber: 2,
              title: 'Obrázek dílu',
              description: 'Simulovaný kontrolovaný díl',
              icon: Icons.photo_camera,
              color: Colors.green,
              isCompleted: _partImagePath != null,
              isEnabled: _referenceImagePath != null,
              onTap: () => _simulatePartCapture(),
            ),
            const SizedBox(height: 30),
            if (_referenceImagePath != null && _partImagePath != null)
              ElevatedButton.icon(
                onPressed: _isCapturing ? null : _startAnalysis,
                icon: _isCapturing 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics),
                label: Text(_isCapturing ? 'Analyzuji...' : 'Spustit AI analýzu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoStep({
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isCompleted,
    bool isEnabled = true,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: isEnabled ? 4 : 1,
      color: isCompleted 
          ? Colors.green[50] 
          : isEnabled 
              ? null 
              : Colors.grey[100],
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withOpacity(0.2)
                      : isEnabled 
                          ? color.withOpacity(0.1) 
                          : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.green, size: 20)
                      : Text(
                          stepNumber.toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isEnabled ? color : Colors.grey,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                icon,
                size: 32,
                color: isCompleted 
                    ? Colors.green 
                    : isEnabled 
                        ? color 
                        : Colors.grey,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isCompleted 
                            ? Colors.green[800] 
                            : isEnabled 
                                ? Colors.black 
                                : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isCompleted 
                            ? Colors.green[600] 
                            : isEnabled 
                                ? Colors.grey[600] 
                                : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isEnabled && !isCompleted)
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _simulateReferenceCapture() async {
    setState(() => _isCapturing = true);
    
    try {
      // Vytvoříme dummy image soubor pro demo
      final imagePath = await _createDummyImageFile('demo_reference_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      setState(() {
        _referenceImagePath = imagePath;
        _isCapturing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Referenční obrázek načten (demo)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isCapturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Chyba při vytváření demo souboru: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _simulatePartCapture() async {
    if (_referenceImagePath == null) return;
    
    setState(() => _isCapturing = true);
    
    try {
      // Vytvoříme dummy image soubor pro demo
      final imagePath = await _createDummyImageFile('demo_part_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      setState(() {
        _partImagePath = imagePath;
        _isCapturing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Obrázek dílu načten (demo)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isCapturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Chyba při vytváření demo souboru: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startAnalysis() async {
    if (_referenceImagePath == null || _partImagePath == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalysisScreen(
          partType: widget.partType,
          referenceImagePath: _referenceImagePath!,
          partImagePath: _partImagePath!,
        ),
      ),
    );
  }

  Future<String> _createDummyImageFile(String fileName) async {
    try {
      // Pro web verzi vytvoříme data URL místo fyzického souboru
      if (kIsWeb) {
        // Pro web používáme jen dummy identifikátor, obrázky se čtou jinak
        
        // Pro web vracíme dočasný identifikátor
        return 'demo_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      }
      
      // Pro mobilní zařízení
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      
      // Validní minimální JPEG obrázek (4x4 pixely) pro Gemini API
      final dummyImageBytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0x10, 0x0B, 0x0C, 0x0E, 0x0C, 0x0A, 0x10, 0x0E, 0x0D, 0x0E, 0x12,
        0x11, 0x10, 0x13, 0x18, 0x28, 0x1A, 0x18, 0x16, 0x16, 0x18, 0x31, 0x23,
        0x25, 0x1D, 0x28, 0x3A, 0x33, 0x3D, 0x3C, 0x39, 0x33, 0x38, 0x37, 0x40,
        0x48, 0x5C, 0x4E, 0x40, 0x44, 0x57, 0x45, 0x37, 0x38, 0x50, 0x6D, 0x51,
        0x57, 0x5F, 0x62, 0x67, 0x68, 0x67, 0x3E, 0x4D, 0x71, 0x79, 0x70, 0x64,
        0x78, 0x5C, 0x65, 0x67, 0x63, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x04,
        0x00, 0x04, 0x01, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
        0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01,
        0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02,
        0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0xFF, 0xC4, 0x00,
        0xB5, 0x10, 0x00, 0x02, 0x01, 0x03, 0x03, 0x02, 0x04, 0x03, 0x05, 0x05,
        0x04, 0x04, 0x00, 0x00, 0x01, 0x7D, 0x01, 0x02, 0x03, 0x00, 0x04, 0x11,
        0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07, 0x22, 0x71,
        0x14, 0x32, 0x81, 0x91, 0xA1, 0x08, 0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52,
        0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0A, 0x16, 0x17, 0x18,
        0x19, 0x1A, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x34, 0x35, 0x36, 0x37,
        0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x53,
        0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67,
        0x68, 0x69, 0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x83,
        0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96,
        0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9,
        0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3,
        0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6,
        0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8,
        0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA,
        0xFF, 0xDA, 0x00, 0x0C, 0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00,
        0x3F, 0x00, 0xF7, 0xFA, 0x28, 0xA2, 0x8A, 0x00, 0x28, 0xA2, 0x8A, 0x00,
        0x28, 0xA2, 0x8A, 0x00, 0x28, 0xA2, 0x8A, 0x00, 0xFF, 0xD9
      ]);
      
      final file = File(filePath);
      await file.writeAsBytes(dummyImageBytes);
      
      return filePath;
    } catch (e) {
      throw Exception('Nepodařilo se vytvořit demo soubor: $e');
    }
  }

  String _getPartTypeDisplayName() {
    switch (widget.partType) {
      case PartType.vylisky:
        return 'Výlisky';
      case PartType.obrabene:
        return 'Obráběné díly';
    }
  }
}