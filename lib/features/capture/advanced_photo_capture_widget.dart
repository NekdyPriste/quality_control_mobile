import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/camera_service.dart';
import '../../core/models/annotation/error_annotation.dart';
import '../annotation/photo_annotation_screen.dart';
import '../../core/services/annotation_export_service.dart';

class AdvancedPhotoCaptureWidget extends ConsumerStatefulWidget {
  final String title;
  final String instruction;
  final Function(File) onPhotoCaptured;
  final VoidCallback onCancel;

  const AdvancedPhotoCaptureWidget({
    super.key,
    required this.title,
    required this.instruction,
    required this.onPhotoCaptured,
    required this.onCancel,
  });

  @override
  ConsumerState<AdvancedPhotoCaptureWidget> createState() => _AdvancedPhotoCaptureWidgetState();
}

class _AdvancedPhotoCaptureWidgetState extends ConsumerState<AdvancedPhotoCaptureWidget>
    with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  File? _capturedImage;

  // Camera controls
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;
  FlashMode _flashMode = FlashMode.auto;
  bool _showControls = true;
  bool _isAutoFocus = true;
  FocusMode _focusMode = FocusMode.auto;
  ExposureMode _exposureMode = ExposureMode.auto;
  double _exposureOffset = 0.0;
  double _minExposureOffset = -4.0;
  double _maxExposureOffset = 4.0;

  // UI state
  bool _showSettings = false;
  late AnimationController _settingsController;
  late Animation<double> _settingsAnimation;

  // Camera features
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;
  bool _hasFlash = false;
  ResolutionPreset _selectedResolution = ResolutionPreset.veryHigh;
  final List<ResolutionPreset> _availableResolutions = [
    ResolutionPreset.low,
    ResolutionPreset.medium,
    ResolutionPreset.high,
    ResolutionPreset.veryHigh,
    ResolutionPreset.ultraHigh,
    ResolutionPreset.max,
  ];

  @override
  void initState() {
    super.initState();
    _settingsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _settingsAnimation = CurvedAnimation(
      parent: _settingsController,
      curve: Curves.easeInOut,
    );
    // No need to initialize camera - using native camera
  }

  @override
  void dispose() {
    _settingsController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraService = ref.read(cameraServiceProvider);
      _controller = await cameraService.getController();

      // Get available cameras
      _availableCameras = await availableCameras();

      if (_controller != null) {
        _minZoom = await _controller!.getMinZoomLevel();
        _maxZoom = await _controller!.getMaxZoomLevel();
        _minExposureOffset = await _controller!.getMinExposureOffset();
        _maxExposureOffset = await _controller!.getMaxExposureOffset();
        _hasFlash = _controller!.description.lensDirection == CameraLensDirection.back;

        // Set initial camera settings for best quality
        await _controller!.setFlashMode(_flashMode);
        await _controller!.setFocusMode(_focusMode);
        await _controller!.setExposureMode(_exposureMode);
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

  Future<void> _switchCamera() async {
    if (_availableCameras.length <= 1) return;

    setState(() => _isInitialized = false);

    _currentCameraIndex = (_currentCameraIndex + 1) % _availableCameras.length;

    await _controller?.dispose();

    try {
      _controller = CameraController(
        _availableCameras[_currentCameraIndex],
        _selectedResolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      await _setOptimalSettings();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při přepínání kamery: $e')),
        );
      }
    }
  }

  Future<void> _setOptimalSettings() async {
    if (_controller == null) return;

    try {
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _minExposureOffset = await _controller!.getMinExposureOffset();
      _maxExposureOffset = await _controller!.getMaxExposureOffset();
      _hasFlash = _controller!.description.lensDirection == CameraLensDirection.back;

      await _controller!.setFlashMode(_flashMode);
      await _controller!.setFocusMode(_focusMode);
      await _controller!.setExposureMode(_exposureMode);
      await _controller!.setZoomLevel(_currentZoom);
      await _controller!.setExposureOffset(_exposureOffset);
    } catch (e) {
      debugPrint('Error setting camera settings: $e');
    }
  }

  Future<void> _onZoomChanged(double zoom) async {
    if (_controller == null || !_isInitialized) return;

    final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
    setState(() => _currentZoom = clampedZoom);

    try {
      await _controller!.setZoomLevel(clampedZoom);
    } catch (e) {
      debugPrint('Error setting zoom: $e');
    }
  }

  Future<void> _onExposureChanged(double exposure) async {
    if (_controller == null || !_isInitialized) return;

    final clampedExposure = exposure.clamp(_minExposureOffset, _maxExposureOffset);
    setState(() => _exposureOffset = clampedExposure);

    try {
      await _controller!.setExposureOffset(clampedExposure);
    } catch (e) {
      debugPrint('Error setting exposure: $e');
    }
  }

  Future<void> _onTapToFocus(TapDownDetails details) async {
    if (_controller == null || !_isInitialized || !_isAutoFocus) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset tapPosition = renderBox.globalToLocal(details.globalPosition);
    final double x = tapPosition.dx / renderBox.size.width;
    final double y = tapPosition.dy / renderBox.size.height;

    try {
      await _controller!.setFocusPoint(Offset(x, y));
      await _controller!.setExposurePoint(Offset(x, y));

      // Show focus indicator
      setState(() {});

      // Hide focus indicator after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint('Error setting focus point: $e');
    }
  }

  Future<void> _captureImage() async {
    // Use native camera for all photo capture - simple and reliable
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (image != null) {
        final capturedFile = File(image.path);
        setState(() {
          _capturedImage = capturedFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při spuštění kamery: $e')),
        );
      }
    }
  }

  void _toggleSettings() {
    setState(() => _showSettings = !_showSettings);
    if (_showSettings) {
      _settingsController.forward();
    } else {
      _settingsController.reverse();
    }
  }

  Future<void> _captureWithNativeCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (image != null) {
        final file = File(image.path);
        setState(() {
          _capturedImage = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při spuštění nativní kamery: $e')),
        );
      }
    }
  }

  void _retakePhoto() {
    setState(() => _capturedImage = null);
  }

  void _acceptPhoto() async {
    if (_capturedImage != null) {
      // Validate file exists and is readable before proceeding
      try {
        final exists = await _capturedImage!.exists();
        if (!exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chyba: Soubor s fotografií neexistuje')),
            );
          }
          return;
        }

        // Validate file size
        final length = await _capturedImage!.length();
        if (length < 1000) { // Less than 1KB indicates corrupted file
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chyba: Poškozený soubor s fotografií')),
            );
          }
          return;
        }

        // File is valid, proceed with callback
        widget.onPhotoCaptured(_capturedImage!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chyba při ověření fotografie: $e')),
          );
        }
      }
    }
  }

  void _captureForAnnotation() async {
    try {
      File? photoFile;

      // First capture the photo using the current camera
      if (!_isInitialized || _isCapturing || _controller == null) {
        // If camera not available, use native camera
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
          maxWidth: 2000,
          maxHeight: 2000,
        );

        if (image != null) {
          photoFile = File(image.path);
        }
      } else {
        // Use in-app camera
        setState(() => _isCapturing = true);

        final image = await _controller!.takePicture();
        photoFile = File(image.path);

        setState(() => _isCapturing = false);
      }

      if (photoFile != null && mounted) {
        // Validate the captured photo
        final exists = await photoFile.exists();
        if (!exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chyba: Nepodarilo se zachytit fotografii')),
            );
          }
          return;
        }

        final length = await photoFile.length();
        if (length < 1000) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chyba: Poškozený soubor fotografie')),
            );
          }
          return;
        }

        // Navigate to annotation screen
        final result = await Navigator.of(context).push<AnnotatedImage>(
          MaterialPageRoute(
            builder: (context) => PhotoAnnotationScreen(
              imageFile: photoFile!,
              partSerialNumber: null, // Optional: could pass from parent
            ),
          ),
        );

        if (result != null && mounted) {
          // Photo was annotated, save to export service
          try {
            final exportService = ref.read(annotationExportServiceProvider);
            final savedPath = await exportService.saveAnnotatedImage(result);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Anotovaná fotografie uložena: ${result.annotations.length} chyb označeno'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );

            // Optional: Show success dialog with export options
            _showAnnotationSuccessDialog(result);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Chyba při ukládání anotace: $e')),
              );
            }
          }
        }
      }
    } catch (e) {
      setState(() => _isCapturing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při spuštění režimu anotace: $e')),
        );
      }
    }
  }

  void _showAnnotationSuccessDialog(AnnotatedImage annotatedImage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anotace dokončena'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Označeno chyb: ${annotatedImage.annotations.length}'),
            const SizedBox(height: 8),
            Text('Kritické: ${annotatedImage.criticalErrors}'),
            Text('Velké: ${annotatedImage.majorErrors}'),
            Text('Malé: ${annotatedImage.minorErrors}'),
            const SizedBox(height: 12),
            const Text('Data byla uložena do místního úložiště.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Optional: Navigate to export/dataset management screen
            },
            child: const Text('Spravovat dataset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _capturedImage != null ? _buildPreview() : _buildCameraInterface();
  }

  Widget _buildCameraInterface() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              widget.instruction,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _captureImage,
              icon: const Icon(Icons.camera_alt, size: 28),
              label: const Text(
                'Spustit kameru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOldCamera() {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: GestureDetector(
              onTapDown: _onTapToFocus,
              onScaleUpdate: (details) {
                final newZoom = _currentZoom * details.scale;
                _onZoomChanged(newZoom);
              },
              child: CameraPreview(_controller!),
            ),
          ),

          // Top controls
          _buildTopControls(),

          // Side controls (zoom, exposure)
          if (_showControls) _buildSideControls(),

          // Bottom controls
          _buildBottomControls(),

          // Settings panel
          if (_showSettings) _buildSettingsPanel(),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          children: [
            // Instruction
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.instruction,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Top buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),

                Row(
                  children: [
                    // Flash control
                    if (_hasFlash) IconButton(
                      onPressed: _cycleFlashMode,
                      icon: Icon(_getFlashIcon(), color: Colors.white, size: 24),
                    ),

                    // Camera switch
                    if (_availableCameras.length > 1) IconButton(
                      onPressed: _switchCamera,
                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 24),
                    ),

                    // Settings
                    IconButton(
                      onPressed: _toggleSettings,
                      icon: Icon(
                        _showSettings ? Icons.settings : Icons.settings_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideControls() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).size.height * 0.3,
      bottom: MediaQuery.of(context).size.height * 0.3,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Zoom control
          _buildVerticalSlider(
            value: _currentZoom,
            min: _minZoom,
            max: _maxZoom,
            onChanged: _onZoomChanged,
            icon: Icons.zoom_in,
            label: '${_currentZoom.toStringAsFixed(1)}x',
          ),

          // Exposure control
          _buildVerticalSlider(
            value: _exposureOffset,
            min: _minExposureOffset,
            max: _maxExposureOffset,
            onChanged: _onExposureChanged,
            icon: Icons.exposure,
            label: '${_exposureOffset.toStringAsFixed(1)}',
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalSlider({
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
    required IconData icon,
    required String label,
  }) {
    return Container(
      height: 120,
      width: 50,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 4),
          Expanded(
            child: RotatedBox(
              quarterTurns: -1,
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
                activeColor: Colors.white,
                inactiveColor: Colors.white30,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
          top: 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Controls toggle
            IconButton(
              onPressed: () => setState(() => _showControls = !_showControls),
              icon: Icon(
                _showControls ? Icons.visibility : Icons.visibility_off,
                color: Colors.white,
                size: 28,
              ),
            ),

            // Capture button
            GestureDetector(
              onTap: _captureImage,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _isCapturing ? Colors.grey : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: _isCapturing
                    ? const Center(child: CircularProgressIndicator(color: Colors.black))
                    : const Icon(Icons.camera_alt, size: 36, color: Colors.black),
              ),
            ),

            // Focus mode toggle
            IconButton(
              onPressed: () => setState(() => _isAutoFocus = !_isAutoFocus),
              icon: Icon(
                _isAutoFocus ? Icons.center_focus_strong : Icons.center_focus_weak,
                color: _isAutoFocus ? Colors.yellow : Colors.white,
                size: 28,
              ),
            ),

            // Native camera button
            IconButton(
              onPressed: _captureWithNativeCamera,
              icon: const Icon(Icons.camera_alt_outlined, color: Colors.green, size: 28),
              tooltip: 'Nativní kamera telefonu',
            ),

            // Annotation mode button
            IconButton(
              onPressed: _captureForAnnotation,
              icon: const Icon(Icons.edit_location, color: Colors.purple, size: 28),
              tooltip: 'Režim označení chyb',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(_settingsAnimation),
        child: Container(
          width: 250,
          color: Colors.black.withOpacity(0.9),
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Nastavení', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      onPressed: _toggleSettings,
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _buildSettingItem('Flash Mode', _getFlashModeText(), Icons.flash_on, _cycleFlashMode),
                _buildSettingItem('Focus Mode', _getFocusModeText(), Icons.center_focus_strong, _cycleFocusMode),
                _buildSettingItem('Exposure Mode', _getExposureModeText(), Icons.exposure, _cycleExposureMode),
                _buildSettingItem('Resolution', _getResolutionText(), Icons.photo_size_select_large, _cycleResolution),

                const SizedBox(height: 20),
                const Text('Zoom Level', style: TextStyle(color: Colors.white)),
                Slider(
                  value: _currentZoom,
                  min: _minZoom,
                  max: _maxZoom,
                  divisions: 20,
                  label: '${_currentZoom.toStringAsFixed(1)}x',
                  onChanged: _onZoomChanged,
                ),

                const SizedBox(height: 10),
                const Text('Exposure Compensation', style: TextStyle(color: Colors.white)),
                Slider(
                  value: _exposureOffset,
                  min: _minExposureOffset,
                  max: _maxExposureOffset,
                  divisions: 40,
                  label: _exposureOffset.toStringAsFixed(1),
                  onChanged: _onExposureChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(String title, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  void _cycleFlashMode() async {
    if (!_hasFlash || _controller == null) return;

    final modes = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final currentIndex = modes.indexOf(_flashMode);
    _flashMode = modes[(currentIndex + 1) % modes.length];

    try {
      await _controller!.setFlashMode(_flashMode);
      setState(() {});
    } catch (e) {
      debugPrint('Error setting flash mode: $e');
    }
  }

  void _cycleFocusMode() async {
    if (_controller == null) return;

    final modes = [FocusMode.auto, FocusMode.locked];
    final currentIndex = modes.indexOf(_focusMode);
    _focusMode = modes[(currentIndex + 1) % modes.length];

    try {
      await _controller!.setFocusMode(_focusMode);
      setState(() {});
    } catch (e) {
      debugPrint('Error setting focus mode: $e');
    }
  }

  void _cycleExposureMode() async {
    if (_controller == null) return;

    final modes = [ExposureMode.auto, ExposureMode.locked];
    final currentIndex = modes.indexOf(_exposureMode);
    _exposureMode = modes[(currentIndex + 1) % modes.length];

    try {
      await _controller!.setExposureMode(_exposureMode);
      setState(() {});
    } catch (e) {
      debugPrint('Error setting exposure mode: $e');
    }
  }

  void _cycleResolution() async {
    final currentIndex = _availableResolutions.indexOf(_selectedResolution);
    final newResolution = _availableResolutions[(currentIndex + 1) % _availableResolutions.length];

    setState(() {
      _selectedResolution = newResolution;
      _isInitialized = false;
    });

    await _controller?.dispose();

    try {
      _controller = CameraController(
        _availableCameras[_currentCameraIndex],
        _selectedResolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      await _setOptimalSettings();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při změně rozlišení: $e')),
        );
        setState(() => _isInitialized = true);
      }
    }
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off: return Icons.flash_off;
      case FlashMode.auto: return Icons.flash_auto;
      case FlashMode.always: return Icons.flash_on;
      case FlashMode.torch: return Icons.flashlight_on;
    }
  }

  String _getFlashModeText() {
    switch (_flashMode) {
      case FlashMode.off: return 'Vypnuto';
      case FlashMode.auto: return 'Automaticky';
      case FlashMode.always: return 'Zapnuto';
      case FlashMode.torch: return 'Svítilna';
    }
  }

  String _getFocusModeText() {
    switch (_focusMode) {
      case FocusMode.auto: return 'Automaticky';
      case FocusMode.locked: return 'Uzamčeno';
    }
  }

  String _getExposureModeText() {
    switch (_exposureMode) {
      case ExposureMode.auto: return 'Automaticky';
      case ExposureMode.locked: return 'Uzamčeno';
    }
  }

  String _getResolutionText() {
    switch (_selectedResolution) {
      case ResolutionPreset.low: return 'Nízké (320p)';
      case ResolutionPreset.medium: return 'Střední (480p)';
      case ResolutionPreset.high: return 'Vysoké (720p)';
      case ResolutionPreset.veryHigh: return 'Velmi vysoké (1080p)';
      case ResolutionPreset.ultraHigh: return 'Ultra vysoké (2160p)';
      case ResolutionPreset.max: return 'Maximum';
    }
  }

  Widget _buildPreview() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Náhled snímku'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: Container(),
      ),
      backgroundColor: Colors.black,
      body: Column(
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _acceptPhoto,
                  icon: const Icon(Icons.check),
                  label: const Text('Použít'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}