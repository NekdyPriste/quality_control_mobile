import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../../core/models/quality_report.dart';
import '../../core/services/camera_service.dart';
import 'part_capture_screen.dart';

class ReferenceCaptureScreen extends ConsumerStatefulWidget {
  final PartType partType;

  const ReferenceCaptureScreen({
    super.key,
    required this.partType,
  });

  @override
  ConsumerState<ReferenceCaptureScreen> createState() => _ReferenceCaptureScreenState();
}

class _ReferenceCaptureScreenState extends ConsumerState<ReferenceCaptureScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  File? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraService = ref.read(cameraServiceProvider);
      _controller = await cameraService.getController();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při inicializaci kamery: $e')),
        );
      }
    }
  }

  Future<void> _captureImage() async {
    if (!_isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final cameraService = ref.read(cameraServiceProvider);
      final image = await cameraService.captureReferenceImage();
      
      setState(() {
        _capturedImage = image;
        _isCapturing = false;
      });
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při fotografování: $e')),
        );
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
    });
  }

  void _acceptPhoto() {
    if (_capturedImage != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PartCaptureScreen(
            partType: widget.partType,
            referenceImagePath: _capturedImage!.path,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referenční snímek'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _capturedImage != null ? _buildPreview() : _buildCamera(),
    );
  }

  Widget _buildCamera() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Row(
            children: [
              const Icon(Icons.info, color: Colors.blue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Vyfotografujte 3D model nebo referenční díl. Zajistěte dobré osvětlení a stabilní záběr.',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: CameraPreview(_controller!),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.black,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
              ),
              GestureDetector(
                onTap: _captureImage,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: _isCapturing ? Colors.grey : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: _isCapturing
                      ? const Center(child: CircularProgressIndicator())
                      : const Icon(Icons.camera_alt, size: 32),
                ),
              ),
              const SizedBox(width: 48), // Spacer for symmetry
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            child: Image.file(
              _capturedImage!,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _retakePhoto,
                icon: const Icon(Icons.refresh),
                label: const Text('Znovu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _acceptPhoto,
                icon: const Icon(Icons.check),
                label: const Text('Pokračovat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}