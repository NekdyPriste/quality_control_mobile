import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/quality_report.dart';
import 'reference_capture_screen.dart';

class CaptureWorkflowScreen extends ConsumerStatefulWidget {
  final PartType partType;

  const CaptureWorkflowScreen({
    super.key,
    required this.partType,
  });

  @override
  ConsumerState<CaptureWorkflowScreen> createState() => _CaptureWorkflowScreenState();
}

class _CaptureWorkflowScreenState extends ConsumerState<CaptureWorkflowScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kontrola - ${_getPartTypeDisplayName()}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              'Kontrola kvality',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Typ dílu: ${_getPartTypeDisplayName()}',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            _buildWorkflowStep(
              stepNumber: 1,
              title: 'Referenční snímek',
              description: 'Vyfotografujte 3D model nebo etalon',
              icon: Icons.photo_library,
              color: Colors.blue,
              onTap: () => _startReferenceCapture(),
            ),
            const SizedBox(height: 16),
            _buildWorkflowStep(
              stepNumber: 2,
              title: 'Snímek dílu',
              description: 'Vyfotografujte kontrolovaný díl',
              icon: Icons.photo_camera,
              color: Colors.green,
              onTap: null, // Disabled until step 1 is complete
            ),
            const SizedBox(height: 16),
            _buildWorkflowStep(
              stepNumber: 3,
              title: 'Analýza',
              description: 'AI analýza a porovnání snímků',
              icon: Icons.analytics,
              color: Colors.orange,
              onTap: null, // Disabled until previous steps complete
            ),
            const SizedBox(height: 40),
            Text(
              'Postupujte podle kroků pro dokončení kontroly',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowStep({
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    
    return Card(
      elevation: isEnabled ? 4 : 1,
      color: isEnabled ? null : Colors.grey[100],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isEnabled ? color.withOpacity(0.1) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
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
                color: isEnabled ? color : Colors.grey,
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
                        color: isEnabled ? Colors.black : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isEnabled ? Colors.grey[600] : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isEnabled)
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

  String _getPartTypeDisplayName() {
    switch (widget.partType) {
      case PartType.vylisky:
        return 'Výlisky';
      case PartType.obrabene:
        return 'Obráběné díly';
    }
  }

  void _startReferenceCapture() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReferenceCaptureScreen(
          partType: widget.partType,
        ),
      ),
    );
  }
}