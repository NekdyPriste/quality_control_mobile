import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import '../models/quality_report.dart';
import '../models/comparison_result.dart';
import '../models/defect.dart';

final datasetExportServiceProvider = Provider<DatasetExportService>((ref) {
  return DatasetExportService();
});

class DatasetExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Export kompletního datasetu pro ML trénování
  Future<String> exportTrainingDataset({
    PartType? partType,
    QualityStatus? resultFilter,
    int? limit = 1000,
    String format = 'jsonl', // 'jsonl', 'json', 'csv'
  }) async {
    final data = await _dbHelper.exportDatasetJson(
      partType: partType,
      resultFilter: resultFilter,
      limit: limit,
    );

    switch (format.toLowerCase()) {
      case 'jsonl':
        return await _exportAsJsonLines(data, partType);
      case 'json':
        return await _exportAsJson(data, partType);
      case 'csv':
        return await _exportAsCsv(data, partType);
      default:
        throw ArgumentError('Unsupported format: $format');
    }
  }

  // Export ve formátu JSONL (pro Gemini fine-tuning)
  Future<String> _exportAsJsonLines(List<Map<String, dynamic>> data, PartType? partType) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final partTypeStr = partType != null 
        ? (partType == PartType.vylisky ? '_vylisky' : '_obrabene')
        : '_all';
    
    final fileName = 'quality_dataset${partTypeStr}_$timestamp.jsonl';
    final file = File('${directory.path}/$fileName');

    final buffer = StringBuffer();
    
    for (final item in data) {
      // Struktura pro Gemini fine-tuning
      final trainingExample = {
        'input': {
          'part_type': item['part_type'],
          'reference_image': item['reference_image'],
          'part_image': item['part_image'],
          'metadata': item['metadata'],
        },
        'output': {
          'overall_quality': item['result'],
          'confidence_score': item['confidence'],
          'defects_found': item['defects'],
          'summary': item['summary'],
        },
        'timestamp': item['timestamp'],
        'id': item['id'],
      };
      
      buffer.writeln(jsonEncode(trainingExample));
    }

    await file.writeAsString(buffer.toString());
    return file.path;
  }

  // Export jako JSON soubor
  Future<String> _exportAsJson(List<Map<String, dynamic>> data, PartType? partType) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final partTypeStr = partType != null 
        ? (partType == PartType.vylisky ? '_vylisky' : '_obrabene')
        : '_all';
    
    final fileName = 'quality_dataset${partTypeStr}_$timestamp.json';
    final file = File('${directory.path}/$fileName');

    final dataset = {
      'metadata': {
        'export_timestamp': DateTime.now().toIso8601String(),
        'total_records': data.length,
        'part_type_filter': partType?.toString(),
        'version': '1.0',
        'description': 'Quality control training dataset for AI model fine-tuning',
      },
      'schema': {
        'input': {
          'part_type': 'string (VÝLISKY|OBRÁBĚNÉ)',
          'reference_image': 'string (file path)',
          'part_image': 'string (file path)',
          'metadata': 'object (operator, line, batch info)',
        },
        'output': {
          'overall_quality': 'string (PASS|FAIL|WARNING)',
          'confidence_score': 'number (0-1)',
          'defects_found': 'array of defect objects',
          'summary': 'string (analysis summary)',
        }
      },
      'data': data,
      'statistics': _calculateDatasetStatistics(data),
    };

    await file.writeAsString(jsonEncode(dataset));
    return file.path;
  }

  // Export jako CSV pro analýzy
  Future<String> _exportAsCsv(List<Map<String, dynamic>> data, PartType? partType) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final partTypeStr = partType != null 
        ? (partType == PartType.vylisky ? '_vylisky' : '_obrabene')
        : '_all';
    
    final fileName = 'quality_dataset${partTypeStr}_$timestamp.csv';
    final file = File('${directory.path}/$fileName');

    final buffer = StringBuffer();
    
    // CSV header
    buffer.writeln('id,timestamp,part_type,result,confidence,defects_count,critical_defects,major_defects,minor_defects,operator,production_line,batch_number,summary');

    // CSV data
    for (final item in data) {
      final defects = item['defects'] as List;
      final criticalCount = defects.where((d) => d['severity'] == 'CRITICAL').length;
      final majorCount = defects.where((d) => d['severity'] == 'MAJOR').length;
      final minorCount = defects.where((d) => d['severity'] == 'MINOR').length;
      
      buffer.writeln([
        item['id'],
        item['timestamp'],
        _escapeCsvValue(item['part_type']),
        item['result'],
        item['confidence'],
        defects.length,
        criticalCount,
        majorCount,
        minorCount,
        _escapeCsvValue(item['metadata']['operator'] ?? ''),
        _escapeCsvValue(item['metadata']['production_line'] ?? ''),
        _escapeCsvValue(item['metadata']['batch_number'] ?? ''),
        _escapeCsvValue(item['summary']),
      ].join(','));
    }

    await file.writeAsString(buffer.toString());
    return file.path;
  }

  // Export defektů pro computer vision trénování  
  Future<String> exportDefectAnnotations({
    PartType? partType,
    DefectType? defectType,
    int? limit = 1000,
  }) async {
    final data = await _dbHelper.exportDatasetJson(
      partType: partType,
      limit: limit,
    );

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'defect_annotations_$timestamp.json';
    final file = File('${directory.path}/$fileName');

    final annotations = <Map<String, dynamic>>[];

    for (final item in data) {
      final defects = item['defects'] as List;
      
      for (final defect in defects) {
        if (defectType == null || _parseDefectType(defect['type']) == defectType) {
          annotations.add({
            'image_path': item['part_image'],
            'reference_image': item['reference_image'],
            'part_type': item['part_type'],
            'defect': {
              'type': defect['type'],
              'description': defect['description'],
              'severity': defect['severity'],
              'bbox': defect['location'], // Bounding box pro YOLO/COCO formát
              'confidence': defect['confidence'],
            },
            'metadata': {
              'inspection_id': item['id'],
              'timestamp': item['timestamp'],
              'overall_result': item['result'],
            }
          });
        }
      }
    }

    final annotationDataset = {
      'info': {
        'description': 'Quality Control Defect Detection Dataset',
        'version': '1.0',
        'year': DateTime.now().year,
        'contributor': 'Quality Control App',
        'date_created': DateTime.now().toIso8601String(),
      },
      'categories': _getDefectCategories(),
      'annotations': annotations,
      'total_annotations': annotations.length,
    };

    await file.writeAsString(jsonEncode(annotationDataset));
    return file.path;
  }

  // Generování syntetického datasetu pro augmentaci
  Future<String> generateSyntheticTrainingExamples({
    required int count,
    PartType? partType,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'synthetic_dataset_$timestamp.jsonl';
    final file = File('${directory.path}/$fileName');

    final buffer = StringBuffer();
    
    for (int i = 0; i < count; i++) {
      final syntheticExample = _generateSyntheticExample(partType);
      buffer.writeln(jsonEncode(syntheticExample));
    }

    await file.writeAsString(buffer.toString());
    return file.path;
  }

  // Export statistik pro analýzu kvality modelu
  Future<Map<String, dynamic>> exportModelPerformanceStats() async {
    final allData = await _dbHelper.exportDatasetJson();
    
    final stats = {
      'dataset_overview': _calculateDatasetStatistics(allData),
      'defect_distribution': _analyzeDefectDistribution(allData),
      'confidence_analysis': _analyzeConfidenceScores(allData),
      'temporal_trends': _analyzeTemporalTrends(allData),
      'quality_metrics': _calculateQualityMetrics(allData),
    };

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'model_performance_stats_$timestamp.json';
    final file = File('${directory.path}/$fileName');

    await file.writeAsString(jsonEncode(stats));
    
    return {
      'statistics': stats,
      'export_path': file.path,
    };
  }

  // Helper methods
  Map<String, dynamic> _calculateDatasetStatistics(List<Map<String, dynamic>> data) {
    final totalRecords = data.length;
    final passCount = data.where((d) => d['result'] == 'PASS').length;
    final failCount = data.where((d) => d['result'] == 'FAIL').length;
    final warningCount = data.where((d) => d['result'] == 'WARNING').length;
    
    final partTypes = <String, int>{};
    final defectTypes = <String, int>{};
    
    for (final item in data) {
      partTypes[item['part_type']] = (partTypes[item['part_type']] ?? 0) + 1;
      
      final defects = item['defects'] as List;
      for (final defect in defects) {
        defectTypes[defect['type']] = (defectTypes[defect['type']] ?? 0) + 1;
      }
    }

    return {
      'total_records': totalRecords,
      'pass_rate': totalRecords > 0 ? passCount / totalRecords : 0,
      'fail_rate': totalRecords > 0 ? failCount / totalRecords : 0,
      'warning_rate': totalRecords > 0 ? warningCount / totalRecords : 0,
      'part_type_distribution': partTypes,
      'defect_type_distribution': defectTypes,
    };
  }

  Map<String, dynamic> _analyzeDefectDistribution(List<Map<String, dynamic>> data) {
    final defectsByType = <String, List<Map<String, dynamic>>>{};
    final severityDistribution = <String, int>{};
    
    for (final item in data) {
      final defects = item['defects'] as List;
      for (final defect in defects) {
        final type = defect['type'] as String;
        final severity = defect['severity'] as String;
        
        defectsByType.putIfAbsent(type, () => []);
        defectsByType[type]!.add(defect);
        
        severityDistribution[severity] = (severityDistribution[severity] ?? 0) + 1;
      }
    }

    return {
      'defects_by_type': defectsByType.map((k, v) => MapEntry(k, v.length)),
      'severity_distribution': severityDistribution,
      'average_defects_per_inspection': data.isEmpty 
          ? 0 
          : defectsByType.values.expand((x) => x).length / data.length,
    };
  }

  Map<String, dynamic> _analyzeConfidenceScores(List<Map<String, dynamic>> data) {
    final confidenceScores = data.map((d) => d['confidence'] as double).toList();
    
    if (confidenceScores.isEmpty) {
      return {'average': 0, 'min': 0, 'max': 0};
    }

    confidenceScores.sort();
    
    return {
      'average': confidenceScores.reduce((a, b) => a + b) / confidenceScores.length,
      'median': confidenceScores[confidenceScores.length ~/ 2],
      'min': confidenceScores.first,
      'max': confidenceScores.last,
      'std_deviation': _calculateStandardDeviation(confidenceScores),
    };
  }

  Map<String, dynamic> _analyzeTemporalTrends(List<Map<String, dynamic>> data) {
    // Analýza trendů v čase - můžeme identifikovat zhoršení výroby
    final dailyStats = <String, Map<String, int>>{};
    
    for (final item in data) {
      final date = DateTime.parse(item['timestamp']).toString().substring(0, 10);
      dailyStats.putIfAbsent(date, () => {'PASS': 0, 'FAIL': 0, 'WARNING': 0});
      dailyStats[date]![item['result']] = (dailyStats[date]![item['result']] ?? 0) + 1;
    }

    return {
      'daily_statistics': dailyStats,
      'trend_analysis': 'Implementation for trend detection',
    };
  }

  Map<String, dynamic> _calculateQualityMetrics(List<Map<String, dynamic>> data) {
    // Metriky pro hodnocení kvality modelu
    return {
      'data_quality_score': _calculateDataQualityScore(data),
      'label_consistency': _analyzeLabelConsistency(data),
      'recommendation': _generateDatasetRecommendations(data),
    };
  }

  double _calculateDataQualityScore(List<Map<String, dynamic>> data) {
    // Skóre kvality dat (0-1)
    double score = 1.0;
    
    // Penalizace za nízkou confidence
    final avgConfidence = data.isEmpty ? 0 : 
        data.map((d) => d['confidence'] as double).reduce((a, b) => a + b) / data.length;
    if (avgConfidence < 0.7) score -= 0.2;
    
    // Penalizace za nevyváženost dat
    final passRate = data.isEmpty ? 0 : 
        data.where((d) => d['result'] == 'PASS').length / data.length;
    if (passRate > 0.9 || passRate < 0.1) score -= 0.3;
    
    return score.clamp(0.0, 1.0);
  }

  double _analyzeLabelConsistency(List<Map<String, dynamic>> data) {
    // Analýza konzistentnosti označování (podobné případy mají podobné výsledky)
    return 0.85; // Placeholder - implementace by porovnala podobné případy
  }

  List<String> _generateDatasetRecommendations(List<Map<String, dynamic>> data) {
    final recommendations = <String>[];
    
    final stats = _calculateDatasetStatistics(data);
    final passRate = stats['pass_rate'] as double;
    
    if (passRate > 0.9) {
      recommendations.add('Dataset obsahuje příliš mnoho pozitivních příkladů. Přidejte více defektních vzorků.');
    }
    
    if (data.length < 100) {
      recommendations.add('Malý dataset. Doporučujeme alespoň 1000 vzorků pro kvalitní trénování.');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('Dataset vypadá dobře pro trénování AI modelu.');
    }
    
    return recommendations;
  }

  List<Map<String, dynamic>> _getDefectCategories() {
    return [
      {'id': 1, 'name': 'MISSING', 'description': 'Chybějící prvky'},
      {'id': 2, 'name': 'EXTRA', 'description': 'Přebývající materiál'},
      {'id': 3, 'name': 'DEFORMED', 'description': 'Deformace tvaru'},
      {'id': 4, 'name': 'DIMENSIONAL', 'description': 'Rozměrové odchylky'},
    ];
  }

  DefectType _parseDefectType(String type) {
    switch (type) {
      case 'MISSING': return DefectType.missing;
      case 'EXTRA': return DefectType.extra;
      case 'DEFORMED': return DefectType.deformed;
      case 'DIMENSIONAL': return DefectType.dimensional;
      default: throw ArgumentError('Unknown defect type: $type');
    }
  }

  Map<String, dynamic> _generateSyntheticExample(PartType? partType) {
    // Generování syntetických příkladů pro augmentaci datasetu
    return {
      'input': {
        'part_type': partType?.toString() ?? 'VÝLISKY',
        'reference_image': 'synthetic_ref_${DateTime.now().millisecondsSinceEpoch}.jpg',
        'part_image': 'synthetic_part_${DateTime.now().millisecondsSinceEpoch}.jpg',
      },
      'output': {
        'overall_quality': 'SYNTHETIC',
        'confidence_score': 0.8,
        'defects_found': [],
        'summary': 'Syntetický příklad pro augmentaci datasetu',
      },
      'synthetic': true,
    };
  }

  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / values.length;
    return variance.sqrt();
  }

  String _escapeCsvValue(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

extension on double {
  double sqrt() => math.sqrt(this);
}