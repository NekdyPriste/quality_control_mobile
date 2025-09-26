import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../../core/services/camera_service.dart';

class PhotoCaptureWidget extends ConsumerStatefulWidget {
  final String title;
  final String instruction;
  final Function(File) onPhotoCaptured;
  final VoidCallback onCancel;

  const PhotoCaptureWidget({
    super.key,
    required this.title,
    required this.instruction,
    required this.onPhotoCaptured,
    required this.onCancel,
  });

  @override
  ConsumerState<PhotoCaptureWidget> createState() => _PhotoCaptureWidgetState();
}

class _PhotoCaptureWidgetState extends ConsumerState<PhotoCaptureWidget> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  File? _capturedImage;

  // Camera controls
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 5.0;
  FlashMode _flashMode = FlashMode.auto;
  bool _showControls = true;
  bool _isAutoFocus = true;

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

      if (_controller != null) {
        _minZoom = await _controller!.getMinZoomLevel();
        _maxZoom = await _controller!.getMaxZoomLevel();
      }

      if (mounted) {
        setState(() => _isInitialized = true);
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

    setState(() => _isCapturing = true);

    try {
      final cameraService = ref.read(cameraServiceProvider);
      final image = await cameraService.captureReferenceImage();

      setState(() {
        _capturedImage = image;
        _isCapturing = false;
      });
    } catch (e) {
      setState(() => _isCapturing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při fotografování: $e')),
        );
      }
    }
  }

  void _retakePhoto() {
    setState(() => _capturedImage = null);
  }

  void _acceptPhoto() {
    if (_capturedImage != null) {
      widget.onPhotoCaptured(_capturedImage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _capturedImage != null ? _buildPreview() : _buildCamera();
  }

  Widget _buildCamera() {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
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
              Expanded(child: Text(widget.instruction, style: const TextStyle(color: Colors.blue))),
            ],
          ),
        ),
        Expanded(child: CameraPreview(_controller!)),
        _buildCameraControls(),
      ],
    );
  }

  Widget _buildCameraControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close, color: Colors.white, size: 32),
          ),
          GestureDetector(
            onTap: _captureImage,
            child: Container(
              width: 70, height: 70,
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
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            child: Image.file(_capturedImage!, fit: BoxFit.contain),
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
                label: const Text('Použít'),
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