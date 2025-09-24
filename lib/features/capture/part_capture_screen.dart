import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/quality_report.dart';
import '../../core/services/camera_service.dart';
import '../analysis/analysis_screen.dart';

class PartCaptureScreen extends ConsumerStatefulWidget {
  final PartType partType;
  final String referenceImagePath;

  const PartCaptureScreen({
    super.key,
    required this.partType,
    required this.referenceImagePath,
  });

  @override
  ConsumerState<PartCaptureScreen> createState() => _PartCaptureScreenState();
}

class _PartCaptureScreenState extends ConsumerState<PartCaptureScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _cameraFailed = false;
  File? _capturedImage;
  final ImagePicker _picker = ImagePicker();

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
          _cameraFailed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraFailed = true;
          _isInitialized = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kamera nedostupná. Použije se výběr ze galerie.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _captureImage() async {
    if (_cameraFailed) {
      // Use image picker instead of camera
      await _pickImageFromGallery();
      return;
    }
    
    if (!_isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final cameraService = ref.read(cameraServiceProvider);
      final image = await cameraService.capturePartImage();
      
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
          builder: (context) => AnalysisScreen(
            partType: widget.partType,
            referenceImagePath: widget.referenceImagePath,
            partImagePath: _capturedImage!.path,
          ),
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při výběru obrázku: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Snímek dílu'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _capturedImage != null ? _buildPreview() : _buildCamera(),
    );
  }

  Widget _buildCamera() {
    if (_cameraFailed) {
      return _buildFallbackUI();
    }
    
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green[50],
          child: Row(
            children: [
              const Icon(Icons.info, color: Colors.green),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Vyfotografujte kontrolovaný díl ze stejného úhlu jako referenční snímek.',
                  style: TextStyle(color: Colors.green),
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
              const SizedBox(width: 48),
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
                label: const Text('Analyzovat'),
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

  Widget _buildFallbackUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Column(
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 80,
                color: Colors.orange.shade600,
              ),
              const SizedBox(height: 16),
              Text(
                'Kamera nedostupná',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Použijte tlačítko níže pro vyfotografování nebo výběr obrázku dílu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: _isCapturing ? null : _captureImage,
          icon: _isCapturing 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_camera),
          label: Text(_isCapturing ? 'Fotografuji...' : 'Vyfotografovat díl'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}