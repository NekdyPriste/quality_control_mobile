import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService();
});

class CameraService {
  List<CameraDescription>? _cameras;
  CameraController? _controller;

  Future<void> initializeCameras() async {
    _cameras = await availableCameras();
  }

  Future<CameraController> getController() async {
    try {
      if (_cameras == null || _cameras!.isEmpty) {
        await initializeCameras();
      }
      
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('Žádné kamery nejsou dostupné na tomto zařízení');
      }

      // Dispose previous controller if exists
      if (_controller != null) {
        await _controller!.dispose();
      }

      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      
      if (!_controller!.value.isInitialized) {
        throw Exception('Kamera se nepodařilo inicializovat');
      }
      
      return _controller!;
    } catch (e) {
      throw Exception('Chyba při inicializaci kamery: $e');
    }
  }

  Future<File> captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }

    final XFile image = await _controller!.takePicture();
    
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fileName = 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String filePath = '${appDir.path}/$fileName';
    
    final File savedImage = await File(image.path).copy(filePath);
    return savedImage;
  }

  Future<File> captureReferenceImage() async {
    final File image = await captureImage();
    
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fileName = 'reference_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String filePath = '${appDir.path}/$fileName';
    
    return await image.copy(filePath);
  }

  Future<File> capturePartImage() async {
    final File image = await captureImage();
    
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fileName = 'part_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String filePath = '${appDir.path}/$fileName';
    
    return await image.copy(filePath);
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}