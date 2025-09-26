import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/annotation/error_annotation.dart';

final annotationExportServiceProvider = Provider<AnnotationExportService>((ref) {
  return AnnotationExportService();
});

enum ExportFormat {
  json,
  cocoFormat,
  yoloFormat,
  csv,
}

class AnnotationExportService {
  static const String _annotationsDir = 'annotations';
  static const String _exportsDir = 'exports';

  // Save single annotated image
  Future<String> saveAnnotatedImage(AnnotatedImage annotatedImage) async {
    final directory = await _getAnnotationsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'annotation_$timestamp.json';
    final file = File(path.join(directory.path, fileName));

    final jsonData = annotatedImage.toJson();
    await file.writeAsString(jsonEncode(jsonData));

    return file.path;
  }

  // Load all annotated images
  Future<List<AnnotatedImage>> loadAllAnnotatedImages() async {
    final directory = await _getAnnotationsDirectory();

    if (!await directory.exists()) {
      return [];
    }

    final files = directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    final List<AnnotatedImage> images = [];

    for (final file in files) {
      try {
        final content = await file.readAsString();
        final jsonData = jsonDecode(content) as Map<String, dynamic>;
        final annotatedImage = AnnotatedImage.fromJson(jsonData);
        images.add(annotatedImage);
      } catch (e) {
        print('Error loading annotation file ${file.path}: $e');
      }
    }

    return images;
  }

  // Export dataset in various formats
  Future<String> exportDataset({
    required List<AnnotatedImage> images,
    required ExportFormat format,
    String? customFileName,
  }) async {
    final directory = await _getExportsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

    String fileName;
    String content;

    switch (format) {
      case ExportFormat.json:
        fileName = customFileName ?? 'dataset_$timestamp.json';
        content = _exportToJSON(images);
        break;

      case ExportFormat.cocoFormat:
        fileName = customFileName ?? 'dataset_coco_$timestamp.json';
        content = _exportToCOCO(images);
        break;

      case ExportFormat.yoloFormat:
        fileName = customFileName ?? 'dataset_yolo_$timestamp.txt';
        content = _exportToYOLO(images);
        break;

      case ExportFormat.csv:
        fileName = customFileName ?? 'dataset_$timestamp.csv';
        content = _exportToCSV(images);
        break;
    }

    final file = File(path.join(directory.path, fileName));
    await file.writeAsString(content);

    return file.path;
  }

  // Export statistics
  Future<String> exportStatistics(List<AnnotatedImage> images) async {
    final directory = await _getExportsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'statistics_$timestamp.json';

    final stats = _calculateStatistics(images);
    final file = File(path.join(directory.path, fileName));
    await file.writeAsString(jsonEncode(stats));

    return file.path;
  }

  // Delete annotation file
  Future<void> deleteAnnotation(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // Get all export files
  Future<List<FileSystemEntity>> getExportFiles() async {
    final directory = await _getExportsDirectory();

    if (!await directory.exists()) {
      return [];
    }

    return directory.listSync().toList();
  }

  // Private helper methods
  Future<Directory> _getAnnotationsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(appDir.path, _annotationsDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _getExportsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(appDir.path, _exportsDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _exportToJSON(List<AnnotatedImage> images) {
    final dataset = {
      'version': '1.0',
      'created_at': DateTime.now().toIso8601String(),
      'total_images': images.length,
      'total_annotations': images.fold(0, (sum, img) => sum + img.annotations.length),
      'statistics': _calculateStatistics(images),
      'images': images.map((img) => img.toMLDatasetFormat()).toList(),
    };

    return jsonEncode(dataset);
  }

  String _exportToCOCO(List<AnnotatedImage> images) {
    final categories = ErrorType.values.asMap().entries.map((entry) {
      return {
        'id': entry.key + 1,
        'name': entry.value.toString().split('.').last,
        'supercategory': 'defect',
      };
    }).toList();

    final cocoImages = <Map<String, dynamic>>[];
    final cocoAnnotations = <Map<String, dynamic>>[];
    int annotationId = 1;

    for (int imageId = 0; imageId < images.length; imageId++) {
      final img = images[imageId];

      cocoImages.add({
        'id': imageId + 1,
        'file_name': path.basename(img.imagePath),
        'width': img.metadata['width'] ?? 0,
        'height': img.metadata['height'] ?? 0,
        'date_captured': img.createdAt.toIso8601String(),
      });

      for (final annotation in img.annotations) {
        final categoryId = ErrorType.values.indexOf(annotation.errorType) + 1;
        final imageWidth = img.metadata['width'] ?? 0;
        final imageHeight = img.metadata['height'] ?? 0;

        cocoAnnotations.add({
          'id': annotationId++,
          'image_id': imageId + 1,
          'category_id': categoryId,
          'bbox': [
            annotation.x * imageWidth,
            annotation.y * imageHeight,
            (annotation.width ?? 0.02) * imageWidth,
            (annotation.height ?? 0.02) * imageHeight,
          ],
          'area': ((annotation.width ?? 0.02) * imageWidth) * ((annotation.height ?? 0.02) * imageHeight),
          'iscrowd': 0,
          'attributes': {
            'severity': annotation.severity.toString().split('.').last,
            'confidence': annotation.confidence,
            'description': annotation.description,
          },
        });
      }
    }

    final cocoFormat = {
      'info': {
        'description': 'Quality Control Defect Dataset',
        'version': '1.0',
        'year': DateTime.now().year,
        'contributor': 'Quality Control Mobile App',
        'date_created': DateTime.now().toIso8601String(),
      },
      'licenses': [
        {
          'id': 1,
          'name': 'Custom License',
          'url': '',
        }
      ],
      'images': cocoImages,
      'annotations': cocoAnnotations,
      'categories': categories,
    };

    return jsonEncode(cocoFormat);
  }

  String _exportToYOLO(List<AnnotatedImage> images) {
    final buffer = StringBuffer();

    for (final img in images) {
      final fileName = path.basenameWithoutExtension(img.imagePath);
      buffer.writeln('# Image: $fileName');

      for (final annotation in img.annotations) {
        final classId = ErrorType.values.indexOf(annotation.errorType);
        final centerX = annotation.x;
        final centerY = annotation.y;
        final width = annotation.width ?? 0.02;
        final height = annotation.height ?? 0.02;

        buffer.writeln('$classId $centerX $centerY $width $height');
      }

      buffer.writeln();
    }

    return buffer.toString();
  }

  String _exportToCSV(List<AnnotatedImage> images) {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln('image_path,annotation_id,x,y,width,height,error_type,severity,confidence,description,timestamp');

    for (final img in images) {
      for (final annotation in img.annotations) {
        buffer.writeln([
          img.imagePath,
          annotation.id,
          annotation.x,
          annotation.y,
          annotation.width ?? '',
          annotation.height ?? '',
          annotation.errorType.toString().split('.').last,
          annotation.severity.toString().split('.').last,
          annotation.confidence,
          '"${annotation.description.replaceAll('"', '""')}"', // Escape quotes in CSV
          annotation.timestamp.toIso8601String(),
        ].join(','));
      }
    }

    return buffer.toString();
  }

  Map<String, dynamic> _calculateStatistics(List<AnnotatedImage> images) {
    final totalImages = images.length;
    final totalAnnotations = images.fold(0, (sum, img) => sum + img.annotations.length);

    final errorTypeCounts = <String, int>{};
    final severityCounts = <String, int>{};
    final confidenceSum = <double>[];

    for (final img in images) {
      for (final annotation in img.annotations) {
        final errorType = annotation.errorType.toString().split('.').last;
        final severity = annotation.severity.toString().split('.').last;

        errorTypeCounts[errorType] = (errorTypeCounts[errorType] ?? 0) + 1;
        severityCounts[severity] = (severityCounts[severity] ?? 0) + 1;
        confidenceSum.add(annotation.confidence);
      }
    }

    final avgConfidence = confidenceSum.isNotEmpty
        ? confidenceSum.reduce((a, b) => a + b) / confidenceSum.length
        : 0.0;

    final imagesWithErrors = images.where((img) => img.annotations.isNotEmpty).length;
    final avgErrorsPerImage = totalImages > 0 ? totalAnnotations / totalImages : 0.0;

    return {
      'total_images': totalImages,
      'images_with_errors': imagesWithErrors,
      'images_without_errors': totalImages - imagesWithErrors,
      'total_annotations': totalAnnotations,
      'avg_errors_per_image': avgErrorsPerImage,
      'avg_confidence': avgConfidence,
      'error_type_distribution': errorTypeCounts,
      'severity_distribution': severityCounts,
      'export_timestamp': DateTime.now().toIso8601String(),
    };
  }
}

// Extension for easy access to display names
extension AnnotatedImageExtension on AnnotatedImage {
  String get displayName {
    final fileName = path.basenameWithoutExtension(imagePath);
    final errorCount = annotations.length;
    return '$fileName ($errorCount chyb)';
  }

  String get shortStats {
    final critical = annotations.where((a) => a.severity == ErrorSeverity.critical).length;
    final major = annotations.where((a) => a.severity == ErrorSeverity.major).length;
    final minor = annotations.where((a) => a.severity == ErrorSeverity.minor).length;

    return 'K:$critical V:$major M:$minor';
  }
}