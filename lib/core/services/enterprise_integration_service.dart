import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quality_report.dart';
import '../models/comparison_result.dart';
import '../models/defect.dart';
import '../database/database_helper.dart';

final enterpriseIntegrationProvider = Provider<EnterpriseIntegrationService>((ref) {
  return EnterpriseIntegrationService();
});

class EnterpriseIntegrationService {
  // Konfigurace pro různé enterprise systemy
  static const String _erpApiUrl = 'https://erp.firma.cz/api/v1';
  static const String _mesApiUrl = 'https://mes.firma.cz/api/v1'; 
  static const String _qmsApiUrl = 'https://qms.firma.cz/api/v1';
  static const String _dataWarehouseUrl = 'https://analytics.firma.cz/api/v1';
  
  static const String _apiKey = 'YOUR_ENTERPRISE_API_KEY';
  static const String _companyId = 'ATQ_SRO';

  // Export do ERP systému (SAP, Oracle, apod.)
  Future<bool> exportToERP({
    required QualityReport report,
    required String workOrderNumber,
    required String articleNumber,
  }) async {
    try {
      final erpData = {
        'company_id': _companyId,
        'work_order': workOrderNumber,
        'article_number': articleNumber,
        'inspection_id': report.id,
        'timestamp': report.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'part_type': _mapPartTypeToERP(report.partType ?? PartType.vylisky),
        'quality_result': _mapQualityStatusToERP(report.comparisonResult?.overallQuality ?? QualityStatus.fail),
        'confidence_score': report.comparisonResult?.confidenceScore ?? 0.0,
        'defects_count': report.comparisonResult?.defectsFound.length ?? 0,
        'defects_summary': report.comparisonResult?.summary ?? 'N/A',
        'critical_defects': report.comparisonResult?.criticalDefects ?? 0,
        'major_defects': report.comparisonResult?.majorDefects ?? 0,
        'minor_defects': report.comparisonResult?.minorDefects ?? 0,
        'operator': 'QC_APP_USER',
        'equipment': 'QUALITY_CONTROL_STATION_01',
      };

      final response = await http.post(
        Uri.parse('$_erpApiUrl/quality/inspections'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'X-Company-ID': _companyId,
        },
        body: jsonEncode(erpData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await _logIntegrationSuccess('ERP', report.id, response.body);
        return true;
      } else {
        await _logIntegrationError('ERP', report.id, 'HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      await _logIntegrationError('ERP', report.id, e.toString());
      return false;
    }
  }

  // Export do MES systému (Manufacturing Execution System)
  Future<bool> exportToMES({
    required QualityReport report,
    required String productionLineId,
    required String batchNumber,
    required String partSerialNumber,
  }) async {
    try {
      final mesData = {
        'production_line_id': productionLineId,
        'batch_number': batchNumber,
        'part_serial': partSerialNumber,
        'inspection_timestamp': report.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'quality_gate_result': (report.comparisonResult?.overallQuality ?? QualityStatus.fail) == QualityStatus.pass ? 'PASS' : 'FAIL',
        'ai_analysis': {
          'model_version': 'gemini-2.5-pro',
          'confidence': report.comparisonResult?.confidenceScore ?? 0.0,
          'defects': (report.comparisonResult?.defectsFound ?? []).map((d) => {
            'type': d.type.toString(),
            'severity': d.severity.toString(),
            'description': d.description,
            'location': {
              'x': d.location.x,
              'y': d.location.y,
              'width': d.location.width,
              'height': d.location.height,
            },
            'confidence': d.confidence,
          }).toList(),
        },
        'process_control': {
          'action_required': (report.comparisonResult?.overallQuality ?? QualityStatus.fail) == QualityStatus.fail,
          'stop_production': (report.comparisonResult?.criticalDefects ?? 0) > 0,
          'alert_supervisor': (report.comparisonResult?.criticalDefects ?? 0) > 0 || (report.comparisonResult?.majorDefects ?? 0) > 2,
        }
      };

      final response = await http.post(
        Uri.parse('$_mesApiUrl/quality-gates'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(mesData),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      await _logIntegrationError('MES', report.id, e.toString());
      return false;
    }
  }

  // Export do QMS systému (Quality Management System)
  Future<bool> exportToQMS({
    required QualityReport report,
    required String inspectorId,
    required String certificationLevel,
  }) async {
    try {
      final qmsData = {
        'inspection_record': {
          'id': report.id,
          'timestamp': report.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
          'inspector_id': inspectorId,
          'certification_level': certificationLevel,
          'inspection_method': 'AI_VISION_ANALYSIS',
          'equipment_calibration': 'VALID',
          'environmental_conditions': 'NORMAL',
        },
        'quality_assessment': {
          'result': _mapQualityStatusToQMS(report.comparisonResult?.overallQuality ?? QualityStatus.fail),
          'confidence_level': _mapConfidenceToQMSLevel(report.comparisonResult?.confidenceScore ?? 0.0),
          'defect_classification': (report.comparisonResult?.defectsFound ?? []).map((d) => {
            'class': _mapDefectTypeToQMS(d.type),
            'severity': _mapDefectSeverityToQMS(d.severity),
            'location': 'X${(d.location.x * 100).round()}Y${(d.location.y * 100).round()}',
            'description': d.description,
          }).toList(),
        },
        'compliance': {
          'standard': 'ISO_9001_2015',
          'traceability_code': '${report.id}_${DateTime.now().millisecondsSinceEpoch}',
          'document_control': 'QC_APP_v1.0',
        }
      };

      final response = await http.post(
        Uri.parse('$_qmsApiUrl/inspection-records'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(qmsData),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      await _logIntegrationError('QMS', report.id, e.toString());
      return false;
    }
  }

  // Synchronizace s datovým skladem pro analytiku
  Future<bool> syncToDataWarehouse({
    required List<QualityReport> reports,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final warehouseData = {
        'sync_metadata': {
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'QUALITY_CONTROL_APP',
          'version': '1.0',
          'record_count': reports.length,
          'date_range': {
            'from': fromDate,
            'to': toDate,
          }
        },
        'quality_data': reports.map((report) => {
          'inspection_id': report.id,
          'timestamp': report.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
          'part_type': (report.partType ?? PartType.vylisky).toString(),
          'result': (report.comparisonResult?.overallQuality ?? QualityStatus.fail).toString(),
          'confidence': report.comparisonResult?.confidenceScore ?? 0.0,
          'defects_summary': {
            'total': report.comparisonResult?.defectsFound.length ?? 0,
            'critical': report.comparisonResult?.criticalDefects ?? 0,
            'major': report.comparisonResult?.majorDefects ?? 0,
            'minor': report.comparisonResult?.minorDefects ?? 0,
          },
          'ai_metrics': {
            'model': 'gemini-2.5-pro',
            'processing_time_ms': 2500, // Placeholder
            'image_quality_score': 0.9, // Placeholder
          }
        }).toList(),
      };

      final response = await http.post(
        Uri.parse('$_dataWarehouseUrl/quality-analytics/bulk-insert'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(warehouseData),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Data warehouse sync error: $e');
      return false;
    }
  }

  // Batch export pro velké množství dat
  Future<Map<String, bool>> batchExportToEnterprise({
    required List<QualityReport> reports,
    required Map<String, dynamic> enterpriseMetadata,
    bool includeERP = true,
    bool includeMES = true,
    bool includeQMS = true,
    bool includeDataWarehouse = true,
  }) async {
    final results = <String, bool>{};

    // Parallel export to different systems
    final futures = <Future<MapEntry<String, bool>>>[];

    if (includeDataWarehouse) {
      futures.add(_exportBatchToDataWarehouse(reports).then((success) => 
          MapEntry('DataWarehouse', success)));
    }

    // Individual exports (for systems that don't support batch)
    for (final report in reports) {
      if (includeERP) {
        futures.add(_exportToERPSingle(report, enterpriseMetadata).then((success) => 
            MapEntry('ERP_${report.id}', success)));
      }
      
      if (includeMES) {
        futures.add(_exportToMESSingle(report, enterpriseMetadata).then((success) => 
            MapEntry('MES_${report.id}', success)));
      }
      
      if (includeQMS) {
        futures.add(_exportToQMSSingle(report, enterpriseMetadata).then((success) => 
            MapEntry('QMS_${report.id}', success)));
      }
    }

    // Wait for all exports to complete
    final completedExports = await Future.wait(futures);
    
    for (final entry in completedExports) {
      results[entry.key] = entry.value;
    }

    return results;
  }

  // Real-time export při každé nové inspekci
  Future<void> realTimeExport({
    required QualityReport report,
    required Map<String, dynamic> productionContext,
  }) async {
    // Async export to all systems without blocking UI
    Future.microtask(() async {
      await Future.wait([
        exportToERP(
          report: report,
          workOrderNumber: productionContext['work_order'] ?? 'UNKNOWN',
          articleNumber: productionContext['article'] ?? 'UNKNOWN',
        ),
        exportToMES(
          report: report,
          productionLineId: productionContext['line_id'] ?? 'LINE_01',
          batchNumber: productionContext['batch'] ?? 'UNKNOWN',
          partSerialNumber: productionContext['serial'] ?? 'UNKNOWN',
        ),
        exportToQMS(
          report: report,
          inspectorId: productionContext['inspector'] ?? 'QC_APP',
          certificationLevel: productionContext['cert_level'] ?? 'LEVEL_2',
        ),
      ]);
    });
  }

  // Helper methods
  Future<bool> _exportBatchToDataWarehouse(List<QualityReport> reports) async {
    return await syncToDataWarehouse(reports: reports);
  }

  Future<bool> _exportToERPSingle(QualityReport report, Map<String, dynamic> metadata) async {
    return await exportToERP(
      report: report,
      workOrderNumber: metadata['work_order'] ?? 'BATCH_EXPORT',
      articleNumber: metadata['article'] ?? 'UNKNOWN',
    );
  }

  Future<bool> _exportToMESSingle(QualityReport report, Map<String, dynamic> metadata) async {
    return await exportToMES(
      report: report,
      productionLineId: metadata['line_id'] ?? 'UNKNOWN',
      batchNumber: metadata['batch'] ?? 'UNKNOWN',
      partSerialNumber: metadata['serial'] ?? 'UNKNOWN',
    );
  }

  Future<bool> _exportToQMSSingle(QualityReport report, Map<String, dynamic> metadata) async {
    return await exportToQMS(
      report: report,
      inspectorId: metadata['inspector'] ?? 'BATCH_EXPORT',
      certificationLevel: metadata['cert_level'] ?? 'LEVEL_2',
    );
  }

  Future<void> _logIntegrationSuccess(String system, int inspectionId, String response) async {
    final dbHelper = DatabaseHelper();
    // Log success to local database
    print('✅ $system integration successful for inspection $inspectionId');
  }

  Future<void> _logIntegrationError(String system, int inspectionId, String error) async {
    final dbHelper = DatabaseHelper();
    // Log error to local database for retry later
    print('❌ $system integration failed for inspection $inspectionId: $error');
  }

  // Mapping methods for different enterprise systems
  String _mapPartTypeToERP(PartType partType) {
    switch (partType) {
      case PartType.vylisky:
        return 'MOLDED_PART';
      case PartType.obrabene:
        return 'MACHINED_PART';
    }
  }

  String _mapQualityStatusToERP(QualityStatus status) {
    switch (status) {
      case QualityStatus.pass:
        return 'ACCEPTED';
      case QualityStatus.fail:
        return 'REJECTED';
      case QualityStatus.warning:
        return 'CONDITIONAL';
    }
  }

  String _mapQualityStatusToQMS(QualityStatus status) {
    switch (status) {
      case QualityStatus.pass:
        return 'CONFORMING';
      case QualityStatus.fail:
        return 'NON_CONFORMING';
      case QualityStatus.warning:
        return 'MARGINAL';
    }
  }

  String _mapConfidenceToQMSLevel(double confidence) {
    if (confidence >= 0.95) return 'HIGH';
    if (confidence >= 0.8) return 'MEDIUM';
    return 'LOW';
  }

  String _mapDefectTypeToQMS(DefectType type) {
    switch (type) {
      case DefectType.missing:
        return 'INCOMPLETE';
      case DefectType.extra:
        return 'EXCESS_MATERIAL';
      case DefectType.deformed:
        return 'DIMENSIONAL_DEVIATION';
      case DefectType.dimensional:
        return 'TOLERANCE_VIOLATION';
    }
  }

  String _mapDefectSeverityToQMS(DefectSeverity severity) {
    switch (severity) {
      case DefectSeverity.critical:
        return 'CRITICAL_NONCONFORMITY';
      case DefectSeverity.major:
        return 'MAJOR_NONCONFORMITY';
      case DefectSeverity.minor:
        return 'MINOR_NONCONFORMITY';
    }
  }
}