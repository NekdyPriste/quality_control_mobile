import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/models/defect.dart';
import '../../../core/models/comparison_result.dart';

class DefectOverlayWidget extends StatefulWidget {
  final String imagePath;
  final ComparisonResult comparisonResult;
  final double imageHeight;
  final double imageWidth;

  const DefectOverlayWidget({
    super.key,
    required this.imagePath,
    required this.comparisonResult,
    required this.imageHeight,
    required this.imageWidth,
  });

  @override
  State<DefectOverlayWidget> createState() => _DefectOverlayWidgetState();
}

class _DefectOverlayWidgetState extends State<DefectOverlayWidget> {
  int? _selectedDefectIndex;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Obrázek dílu
        _buildImageWidget(),
        
        // Overlay s označením defektů
        Positioned.fill(
          child: Stack(
            children: widget.comparisonResult.defectsFound
                .asMap()
                .entries
                .map((entry) {
              final index = entry.key;
              final defect = entry.value;
              return _buildDefectMarker(defect, index);
            }).toList(),
          ),
        ),
        
        // Info panel pro vybraný defekt
        if (_selectedDefectIndex != null)
          _buildDefectInfoPanel(widget.comparisonResult.defectsFound[_selectedDefectIndex!]),
      ],
    );
  }

  Widget _buildDefectMarker(Defect defect, int index) {
    final isSelected = _selectedDefectIndex == index;
    final color = _getDefectColor(defect.severity);
    
    // Převod relativních souřadnic na pixely
    final left = defect.location.x * widget.imageWidth;
    final top = defect.location.y * widget.imageHeight;
    final width = defect.location.width * widget.imageWidth;
    final height = defect.location.height * widget.imageHeight;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDefectIndex = isSelected ? null : index;
          });
        },
        child: Container(
          width: width.clamp(20.0, widget.imageWidth),
          height: height.clamp(20.0, widget.imageHeight),
          decoration: BoxDecoration(
            border: Border.all(
              color: color,
              width: isSelected ? 3.0 : 2.0,
            ),
            borderRadius: BorderRadius.circular(4),
            color: color.withOpacity(isSelected ? 0.3 : 0.1),
          ),
          child: Stack(
            children: [
              // Křížek pro označení středu defektu
              Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Pulsující animace pro kritické defekty
              if (defect.severity == DefectSeverity.critical && isSelected)
                Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefectInfoPanel(Defect defect) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getDefectColor(defect.severity),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getDefectColor(defect.severity),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getDefectTypeText(defect.type),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      _getSeverityText(defect.severity),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: _getDefectColor(defect.severity),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                defect.description,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pozice: (${(defect.location.x * 100).round()}%, ${(defect.location.y * 100).round()}%)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    'Jistota: ${(defect.confidence * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDefectColor(DefectSeverity severity) {
    switch (severity) {
      case DefectSeverity.critical:
        return Colors.red;
      case DefectSeverity.major:
        return Colors.orange;
      case DefectSeverity.minor:
        return Colors.yellow.shade700;
    }
  }

  String _getDefectTypeText(DefectType type) {
    switch (type) {
      case DefectType.missing:
        return 'Chybějící prvek';
      case DefectType.extra:
        return 'Přebývající materiál';
      case DefectType.deformed:
        return 'Deformace';
      case DefectType.dimensional:
        return 'Rozměrová odchylka';
    }
  }

  String _getSeverityText(DefectSeverity severity) {
    switch (severity) {
      case DefectSeverity.critical:
        return 'KRITICKÝ';
      case DefectSeverity.major:
        return 'ZÁVAŽNÝ';
      case DefectSeverity.minor:
        return 'MENŠÍ';
    }
  }

  Widget _buildImageWidget() {
    // Pro web režim nebo demo, zobrazíme placeholder s informací
    if (kIsWeb || widget.imagePath.startsWith('demo_')) {
      return Container(
        height: widget.imageHeight,
        width: widget.imageWidth,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              size: 48,
              color: Colors.blue.shade300,
            ),
            const SizedBox(height: 8),
            const Text(
              'Demo obrázek dílu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Na tomto obrázku by byly\nzobrazeny defekty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // Pro mobilní zařízení
    return Image.file(
      File(widget.imagePath),
      height: widget.imageHeight,
      width: widget.imageWidth,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: widget.imageHeight,
          width: widget.imageWidth,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            border: Border.all(color: Colors.red.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 48, color: Colors.red),
              SizedBox(height: 8),
              Text(
                'Chyba načítání obrázku',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        );
      },
    );
  }
}