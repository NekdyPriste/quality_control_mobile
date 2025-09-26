import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/quality_report.dart';
import 'part_capture_screen.dart';
import 'unified_photo_capture_screen.dart';

class ReferenceCaptureScreen extends ConsumerWidget {
  final PartType partType;

  const ReferenceCaptureScreen({
    super.key,
    required this.partType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UnifiedPhotoCaptureScreen(
      title: 'Referenční snímek',
      instruction: 'Vyfotografujte 3D model nebo referenční díl. Zajistěte dobré osvětlení a stabilní záběr.',
      captureTwo: false,
      onOnePhotoCaptured: (photo) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PartCaptureScreen(
              partType: partType,
              referenceImagePath: photo.path,
            ),
          ),
        );
      },
    );
  }
}