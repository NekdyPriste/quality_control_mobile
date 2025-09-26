import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/annotation/error_annotation.dart';

class PhotoAnnotationScreen extends ConsumerStatefulWidget {
  final File imageFile;
  final String? partSerialNumber;

  const PhotoAnnotationScreen({
    super.key,
    required this.imageFile,
    this.partSerialNumber,
  });

  @override
  ConsumerState<PhotoAnnotationScreen> createState() => _PhotoAnnotationScreenState();
}

class _PhotoAnnotationScreenState extends ConsumerState<PhotoAnnotationScreen> {
  final List<ErrorAnnotation> _annotations = [];
  Size? _imageSize;
  final GlobalKey _imageKey = GlobalKey();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    final imageBytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    setState(() {
      _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      _isLoading = false;
    });
  }

  void _onImageTap(TapDownDetails details) {
    if (_imageSize == null) return;

    final RenderBox? renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final imageWidget = renderBox.size;

    // Calculate aspect ratio and actual image display size
    final imageAspectRatio = _imageSize!.width / _imageSize!.height;
    final widgetAspectRatio = imageWidget.width / imageWidget.height;

    late Size displaySize;
    late Offset offset;

    if (imageAspectRatio > widgetAspectRatio) {
      // Image is wider, fit to width
      displaySize = Size(imageWidget.width, imageWidget.width / imageAspectRatio);
      offset = Offset(0, (imageWidget.height - displaySize.height) / 2);
    } else {
      // Image is taller, fit to height
      displaySize = Size(imageWidget.height * imageAspectRatio, imageWidget.height);
      offset = Offset((imageWidget.width - displaySize.width) / 2, 0);
    }

    // Adjust tap position relative to actual image display area
    final adjustedPosition = localPosition - offset;

    // Check if tap is within image bounds
    if (adjustedPosition.dx < 0 || adjustedPosition.dx > displaySize.width ||
        adjustedPosition.dy < 0 || adjustedPosition.dy > displaySize.height) {
      return;
    }

    // Convert to relative coordinates (0-1)
    final relativeX = adjustedPosition.dx / displaySize.width;
    final relativeY = adjustedPosition.dy / displaySize.height;

    _showErrorAnnotationDialog(relativeX, relativeY);
  }

  void _showErrorAnnotationDialog(double x, double y) {
    showDialog<ErrorAnnotation>(
      context: context,
      builder: (context) => ErrorAnnotationDialog(x: x, y: y),
    ).then((annotation) {
      if (annotation != null) {
        setState(() {
          _annotations.add(annotation);
        });
      }
    });
  }

  void _removeAnnotation(ErrorAnnotation annotation) {
    setState(() {
      _annotations.remove(annotation);
    });
  }

  void _editAnnotation(ErrorAnnotation annotation) {
    showDialog<ErrorAnnotation>(
      context: context,
      builder: (context) => ErrorAnnotationDialog(
        x: annotation.x,
        y: annotation.y,
        existingAnnotation: annotation,
      ),
    ).then((updatedAnnotation) {
      if (updatedAnnotation != null) {
        setState(() {
          final index = _annotations.indexOf(annotation);
          if (index != -1) {
            _annotations[index] = updatedAnnotation;
          }
        });
      }
    });
  }

  void _saveAnnotations() async {
    if (_annotations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nejsou označeny žádné chyby')),
      );
      return;
    }

    final annotatedImage = AnnotatedImage(
      imagePath: widget.imageFile.path,
      annotations: _annotations,
      metadata: {
        'width': _imageSize?.width ?? 0,
        'height': _imageSize?.height ?? 0,
        'device_info': 'Flutter App',
        'annotation_method': 'manual_tap',
      },
      createdAt: DateTime.now(),
      partSerialNumber: widget.partSerialNumber,
      operatorId: 'current_user', // TODO: Get from user session
    );

    // TODO: Save to database or export
    // For now, just show success and return the result
    Navigator.of(context).pop(annotatedImage);
  }

  Widget _buildAnnotationMarker(ErrorAnnotation annotation, Size displaySize, Offset offset) {
    final position = Offset(
      annotation.x * displaySize.width + offset.dx,
      annotation.y * displaySize.height + offset.dy,
    );

    return Positioned(
      left: position.dx - 12,
      top: position.dy - 12,
      child: GestureDetector(
        onTap: () => _editAnnotation(annotation),
        onLongPress: () => _removeAnnotation(annotation),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: annotation.markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${_annotations.indexOf(annotation) + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Označení chyb'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_annotations.isNotEmpty)
            IconButton(
              onPressed: _saveAnnotations,
              icon: const Icon(Icons.save),
              tooltip: 'Uložit anotace',
            ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.touch_app, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tapněte na fotografii pro označení chyby',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (_annotations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Označeno chyb: ${_annotations.length}',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ],
              ],
            ),
          ),

          // Image with annotations
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.grey[200],
              child: Stack(
                children: [
                  // Image
                  Center(
                    child: GestureDetector(
                      key: _imageKey,
                      onTapDown: _onImageTap,
                      child: Image.file(
                        widget.imageFile,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Annotation markers
                  if (_imageSize != null) ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final imageAspectRatio = _imageSize!.width / _imageSize!.height;
                        final widgetAspectRatio = constraints.maxWidth / constraints.maxHeight;

                        late Size displaySize;
                        late Offset offset;

                        if (imageAspectRatio > widgetAspectRatio) {
                          displaySize = Size(constraints.maxWidth, constraints.maxWidth / imageAspectRatio);
                          offset = Offset(0, (constraints.maxHeight - displaySize.height) / 2);
                        } else {
                          displaySize = Size(constraints.maxHeight * imageAspectRatio, constraints.maxHeight);
                          offset = Offset((constraints.maxWidth - displaySize.width) / 2, 0);
                        }

                        return Stack(
                          children: _annotations
                              .map((annotation) => _buildAnnotationMarker(annotation, displaySize, offset))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Error list
          if (_annotations.isNotEmpty)
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: _annotations.length,
                itemBuilder: (context, index) {
                  final annotation = _annotations[index];
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: annotation.markerColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    annotation.errorTypeDisplayName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              annotation.severityDisplayName,
                              style: TextStyle(
                                color: annotation.markerColor,
                                fontSize: 12,
                              ),
                            ),
                            if (annotation.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                annotation.description,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: _annotations.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _saveAnnotations,
              icon: const Icon(Icons.save),
              label: Text('Uložit (${_annotations.length})'),
            )
          : null,
    );
  }
}

class ErrorAnnotationDialog extends StatefulWidget {
  final double x;
  final double y;
  final ErrorAnnotation? existingAnnotation;

  const ErrorAnnotationDialog({
    super.key,
    required this.x,
    required this.y,
    this.existingAnnotation,
  });

  @override
  State<ErrorAnnotationDialog> createState() => _ErrorAnnotationDialogState();
}

class _ErrorAnnotationDialogState extends State<ErrorAnnotationDialog> {
  late ErrorType _selectedErrorType;
  late ErrorSeverity _selectedSeverity;
  late TextEditingController _descriptionController;
  double _confidence = 1.0;

  @override
  void initState() {
    super.initState();
    _selectedErrorType = widget.existingAnnotation?.errorType ?? ErrorType.other;
    _selectedSeverity = widget.existingAnnotation?.severity ?? ErrorSeverity.minor;
    _descriptionController = TextEditingController(
      text: widget.existingAnnotation?.description ?? '',
    );
    _confidence = widget.existingAnnotation?.confidence ?? 1.0;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingAnnotation == null ? 'Nová chyba' : 'Upravit chybu'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error Type
            const Text('Typ chyby:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<ErrorType>(
              isExpanded: true,
              value: _selectedErrorType,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedErrorType = value);
                }
              },
              items: ErrorType.values.map((type) {
                final annotation = ErrorAnnotation(
                  id: '',
                  x: 0,
                  y: 0,
                  errorType: type,
                  severity: ErrorSeverity.minor,
                  description: '',
                  timestamp: DateTime.now(),
                );
                return DropdownMenuItem(
                  value: type,
                  child: Text(annotation.errorTypeDisplayName),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Severity
            const Text('Závažnost:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<ErrorSeverity>(
              isExpanded: true,
              value: _selectedSeverity,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedSeverity = value);
                }
              },
              items: ErrorSeverity.values.map((severity) {
                final annotation = ErrorAnnotation(
                  id: '',
                  x: 0,
                  y: 0,
                  errorType: ErrorType.other,
                  severity: severity,
                  description: '',
                  timestamp: DateTime.now(),
                );
                return DropdownMenuItem(
                  value: severity,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: annotation.markerColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(annotation.severityDisplayName),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Description
            const Text('Popis:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Popište chybu...',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Confidence
            const Text('Jistota:', style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _confidence,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              label: '${(_confidence * 100).round()}%',
              onChanged: (value) {
                setState(() => _confidence = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zrušit'),
        ),
        ElevatedButton(
          onPressed: () {
            final annotation = ErrorAnnotation(
              id: widget.existingAnnotation?.id ?? const Uuid().v4(),
              x: widget.x,
              y: widget.y,
              errorType: _selectedErrorType,
              severity: _selectedSeverity,
              description: _descriptionController.text.trim(),
              timestamp: widget.existingAnnotation?.timestamp ?? DateTime.now(),
              confidence: _confidence,
            );
            Navigator.of(context).pop(annotation);
          },
          child: const Text('Uložit'),
        ),
      ],
    );
  }
}