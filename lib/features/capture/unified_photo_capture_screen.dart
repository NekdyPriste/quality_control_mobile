import 'dart:io';
import 'package:flutter/material.dart';
import 'advanced_photo_capture_widget.dart';

class UnifiedPhotoCaptureScreen extends StatefulWidget {
  final String title;
  final String instruction;
  final bool captureTwo; // true pro batch (2 fotky), false pro jednotlivou analýzu
  final Function(File, File?)? onTwoPhotoCaptured; // For batch
  final Function(File)? onOnePhotoCaptured; // For individual

  const UnifiedPhotoCaptureScreen({
    super.key,
    required this.title,
    required this.instruction,
    this.captureTwo = false,
    this.onTwoPhotoCaptured,
    this.onOnePhotoCaptured,
  });

  @override
  State<UnifiedPhotoCaptureScreen> createState() => _UnifiedPhotoCaptureScreenState();
}

class _UnifiedPhotoCaptureScreenState extends State<UnifiedPhotoCaptureScreen> {
  File? _firstPhoto;
  bool _isCapturingSecond = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: AdvancedPhotoCaptureWidget(
        title: _getTitle(),
        instruction: _getInstruction(),
        onPhotoCaptured: _handlePhotoCaptured,
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  String _getTitle() {
    if (!widget.captureTwo) return widget.title;
    return _firstPhoto == null ? 'Referenční snímek' : 'Snímek dílu';
  }

  String _getInstruction() {
    if (!widget.captureTwo) return widget.instruction;

    if (_firstPhoto == null) {
      return 'Vyfotografujte referenční díl nebo 3D model. Zajistěte dobré osvětlení a stabilní záběr.';
    } else {
      return 'Vyfotografujte kontrolovaný díl. Udržte stejný úhel a vzdálenost jako u referenčního snímku.';
    }
  }

  void _handlePhotoCaptured(File photo) {
    if (!widget.captureTwo) {
      // Individual analysis - just one photo
      widget.onOnePhotoCaptured?.call(photo);
      Navigator.pop(context, photo);
      return;
    }

    // Batch analysis - two photos
    if (_firstPhoto == null) {
      // First photo captured, prepare for second
      setState(() {
        _firstPhoto = photo;
        _isCapturingSecond = true;
      });
    } else {
      // Second photo captured, return both
      widget.onTwoPhotoCaptured?.call(_firstPhoto!, photo);
      Navigator.pop(context, {
        'reference': _firstPhoto!,
        'part': photo,
      });
    }
  }
}