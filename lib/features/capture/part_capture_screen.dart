import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/quality_report.dart';
import '../analysis/enhanced_analysis_screen.dart';
import '../../core/models/quality/enhanced_confidence_score.dart';
import 'unified_photo_capture_screen.dart';

class PartCaptureScreen extends ConsumerWidget {
  final PartType partType;
  final String referenceImagePath;

  const PartCaptureScreen({
    super.key,
    required this.partType,
    required this.referenceImagePath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UnifiedPhotoCaptureScreen(
      title: 'Snímek dílu',
      instruction: 'Vyfotografujte kontrolovaný díl. Udržte stejný úhel a vzdálenost jako u referenčního snímku.',
      captureTwo: false,
      onOnePhotoCaptured: (photo) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EnhancedAnalysisScreen(
              referenceImagePath: referenceImagePath,
              partImagePath: photo.path,
              partType: partType,
              complexity: AnalysisComplexity.moderate,
            ),
          ),
        );
      },
    );
  }
}