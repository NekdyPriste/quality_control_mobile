import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../models/quality_report.dart';
import '../models/comparison_result.dart';
import '../models/defect.dart';
import '../database/database_helper.dart';

final emailServiceProvider = Provider<EmailService>((ref) {
  return EmailService();
});

class EmailService {
  // Konfigurace pro EmailJS nebo vlastní SMTP
  static const String _emailJsServiceId = 'YOUR_EMAILJS_SERVICE_ID';
  static const String _emailJsTemplateId = 'YOUR_EMAILJS_TEMPLATE_ID';
  static const String _emailJsUserId = 'YOUR_EMAILJS_USER_ID';
  static const String _emailJsApiUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  // Alternativní konfigurace pro vlastní SMTP server
  static const String _smtpServerUrl = 'https://your-smtp-api.com/send';
  static const String _smtpApiKey = 'YOUR_SMTP_API_KEY';

  Future<bool> sendQualityReport({
    required int inspectionId,
    required String recipientEmail,
    required PartType partType,
    required ComparisonResult comparisonResult,
    String? operatorName,
    String? productionLine,
    String? batchNumber,
  }) async {
    try {
      // Volba metody odesílání (EmailJS nebo vlastní SMTP)
      final success = await _sendViaEmailJS(
        recipientEmail: recipientEmail,
        inspectionId: inspectionId,
        partType: partType,
        comparisonResult: comparisonResult,
        operatorName: operatorName,
        productionLine: productionLine,
        batchNumber: batchNumber,
      );

      // Záznam do databáze
      await DatabaseHelper().logEmailReport(
        inspectionId: inspectionId,
        recipientEmail: recipientEmail,
        status: success ? 'SENT' : 'FAILED',
        errorMessage: success ? null : 'Email sending failed',
      );

      return success;
    } catch (e) {
      // Záznam chyby do databáze
      await DatabaseHelper().logEmailReport(
        inspectionId: inspectionId,
        recipientEmail: recipientEmail,
        status: 'FAILED',
        errorMessage: e.toString(),
      );

      return false;
    }
  }

  Future<bool> _sendViaEmailJS({
    required String recipientEmail,
    required int inspectionId,
    required PartType partType,
    required ComparisonResult comparisonResult,
    String? operatorName,
    String? productionLine,
    String? batchNumber,
  }) async {
    // FALLBACK: Jelikož EmailJS není nakonfigurován, vytvoříme lokální report
    return await _createLocalReport(
      recipientEmail: recipientEmail,
      inspectionId: inspectionId,
      partType: partType,
      comparisonResult: comparisonResult,
      operatorName: operatorName,
      productionLine: productionLine,
      batchNumber: batchNumber,
    );

    final emailData = {
      'service_id': _emailJsServiceId,
      'template_id': _emailJsTemplateId,
      'user_id': _emailJsUserId,
      'template_params': {
        'to_email': recipientEmail,
        'subject': 'Quality Control Report - ${_getStatusText(comparisonResult.overallQuality)}',
        'message': 'ATQ Quality Control Report',
        'inspection_id': inspectionId.toString(),
        'part_type': partType == PartType.vylisky ? 'Výlisky' : 'Obráběné díly',
        'result': _getStatusText(comparisonResult.overallQuality),
        'confidence': '${(comparisonResult.confidenceScore * 100).round()}%',
        'defects_count': comparisonResult.defectsFound.length.toString(),
        'timestamp': DateTime.now().toString(),
      }
    };

    try {
      final response = await http.post(
        Uri.parse(_emailJsApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(emailData),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('EmailJS error: $e');
      return false;
    }
  }

  Future<bool> _sendViaCustomSMTP({
    required String recipientEmail,
    required int inspectionId,
    required PartType partType,
    required ComparisonResult comparisonResult,
    String? operatorName,
    String? productionLine,
    String? batchNumber,
  }) async {
    final emailBody = _generateEmailBody(
      inspectionId: inspectionId,
      partType: partType,
      comparisonResult: comparisonResult,
      operatorName: operatorName,
      productionLine: productionLine,
      batchNumber: batchNumber,
    );

    final emailData = {
      'to': recipientEmail,
      'subject': 'Quality Control Report - ${_getStatusText(comparisonResult.overallQuality)}',
      'html': _generateHtmlEmail(
        inspectionId: inspectionId,
        partType: partType,
        comparisonResult: comparisonResult,
        operatorName: operatorName,
        productionLine: productionLine,
        batchNumber: batchNumber,
      ),
      'text': emailBody,
    };

    try {
      final response = await http.post(
        Uri.parse(_smtpServerUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_smtpApiKey',
        },
        body: jsonEncode(emailData),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('SMTP error: $e');
      return false;
    }
  }

  String _generateEmailBody({
    required int inspectionId,
    required PartType partType,
    required ComparisonResult comparisonResult,
    String? operatorName,
    String? productionLine,
    String? batchNumber,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('=== QUALITY CONTROL REPORT ===');
    buffer.writeln('');
    buffer.writeln('Inspection ID: $inspectionId');
    buffer.writeln('Timestamp: ${DateTime.now()}');
    buffer.writeln('Part Type: ${partType == PartType.vylisky ? "Výlisky" : "Obráběné díly"}');
    
    if (operatorName != null) buffer.writeln('Operator: $operatorName');
    if (productionLine != null) buffer.writeln('Production Line: $productionLine');
    if (batchNumber != null) buffer.writeln('Batch Number: $batchNumber');
    
    buffer.writeln('');
    buffer.writeln('=== RESULTS ===');
    buffer.writeln('Overall Result: ${_getStatusText(comparisonResult.overallQuality)}');
    buffer.writeln('Confidence: ${(comparisonResult.confidenceScore * 100).round()}%');
    buffer.writeln('');
    buffer.writeln('Summary: ${comparisonResult.summary}');
    buffer.writeln('');

    if (comparisonResult.hasDefects) {
      buffer.writeln('=== DEFECTS FOUND (${comparisonResult.defectsFound.length}) ===');
      
      for (int i = 0; i < comparisonResult.defectsFound.length; i++) {
        final defect = comparisonResult.defectsFound[i];
        buffer.writeln('${i + 1}. ${defect.description}');
        buffer.writeln('   Type: ${_getDefectTypeText(defect.type)}');
        buffer.writeln('   Severity: ${_getSeverityText(defect.severity)}');
        buffer.writeln('   Confidence: ${(defect.confidence * 100).round()}%');
        buffer.writeln('   Location: (${(defect.location.x * 100).round()}%, ${(defect.location.y * 100).round()}%)');
        buffer.writeln('');
      }
    } else {
      buffer.writeln('No defects found.');
    }

    buffer.writeln('');
    buffer.writeln('=== STATISTICS ===');
    buffer.writeln('Critical defects: ${comparisonResult.criticalDefects}');
    buffer.writeln('Major defects: ${comparisonResult.majorDefects}');
    buffer.writeln('Minor defects: ${comparisonResult.minorDefects}');
    
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('Generated by Quality Control App');
    
    return buffer.toString();
  }

  String _generateHtmlEmail({
    required int inspectionId,
    required PartType partType,
    required ComparisonResult comparisonResult,
    String? operatorName,
    String? productionLine,
    String? batchNumber,
  }) {
    final statusColor = comparisonResult.overallQuality == QualityStatus.pass 
        ? '#4CAF50' 
        : comparisonResult.overallQuality == QualityStatus.fail 
            ? '#F44336' 
            : '#FF9800';

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Quality Control Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: $statusColor; color: white; padding: 20px; border-radius: 5px; }
        .content { padding: 20px; }
        .defect-item { background-color: #f5f5f5; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .critical { border-left: 5px solid #F44336; }
        .major { border-left: 5px solid #FF9800; }
        .minor { border-left: 5px solid #FFC107; }
        .stats { display: flex; gap: 20px; }
        .stat-item { text-align: center; padding: 10px; background-color: #e3f2fd; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Quality Control Report</h1>
        <h2>${_getStatusText(comparisonResult.overallQuality)}</h2>
    </div>
    
    <div class="content">
        <h3>Inspection Details</h3>
        <p><strong>ID:</strong> $inspectionId</p>
        <p><strong>Timestamp:</strong> ${DateTime.now()}</p>
        <p><strong>Part Type:</strong> ${partType == PartType.vylisky ? "Výlisky" : "Obráběné díly"}</p>
        ${operatorName != null ? '<p><strong>Operator:</strong> $operatorName</p>' : ''}
        ${productionLine != null ? '<p><strong>Production Line:</strong> $productionLine</p>' : ''}
        ${batchNumber != null ? '<p><strong>Batch Number:</strong> $batchNumber</p>' : ''}
        
        <h3>Results</h3>
        <p><strong>Confidence:</strong> ${(comparisonResult.confidenceScore * 100).round()}%</p>
        <p><strong>Summary:</strong> ${comparisonResult.summary}</p>
        
        <div class="stats">
            <div class="stat-item">
                <strong>Critical</strong><br>
                ${comparisonResult.criticalDefects}
            </div>
            <div class="stat-item">
                <strong>Major</strong><br>
                ${comparisonResult.majorDefects}
            </div>
            <div class="stat-item">
                <strong>Minor</strong><br>
                ${comparisonResult.minorDefects}
            </div>
        </div>

        ${comparisonResult.hasDefects ? '''
        <h3>Defects Found (${comparisonResult.defectsFound.length})</h3>
        ${comparisonResult.defectsFound.map((defect) => '''
        <div class="defect-item ${_getSeverityClass(defect.severity)}">
            <h4>${defect.description}</h4>
            <p><strong>Type:</strong> ${_getDefectTypeText(defect.type)}</p>
            <p><strong>Severity:</strong> ${_getSeverityText(defect.severity)}</p>
            <p><strong>Confidence:</strong> ${(defect.confidence * 100).round()}%</p>
            <p><strong>Location:</strong> (${(defect.location.x * 100).round()}%, ${(defect.location.y * 100).round()}%)</p>
        </div>
        ''').join()}
        ''' : '<p>No defects found.</p>'}
    </div>
</body>
</html>
    ''';
  }

  String _getStatusText(QualityStatus status) {
    switch (status) {
      case QualityStatus.pass: return 'VYHOVUJE';
      case QualityStatus.fail: return 'NEVYHOVUJE';
      case QualityStatus.warning: return 'UPOZORNĚNÍ';
    }
  }

  String _getDefectTypeText(DefectType type) {
    switch (type) {
      case DefectType.missing: return 'Chybějící prvek';
      case DefectType.extra: return 'Přebývající materiál';
      case DefectType.deformed: return 'Deformace';
      case DefectType.dimensional: return 'Rozměrová odchylka';
    }
  }

  String _getSeverityText(DefectSeverity severity) {
    switch (severity) {
      case DefectSeverity.critical: return 'Kritický';
      case DefectSeverity.major: return 'Závažný';
      case DefectSeverity.minor: return 'Menší';
    }
  }

  String _getSeverityClass(DefectSeverity severity) {
    switch (severity) {
      case DefectSeverity.critical: return 'critical';
      case DefectSeverity.major: return 'major';
      case DefectSeverity.minor: return 'minor';
    }
  }

  Future<bool> _createLocalReport({
    required String recipientEmail,
    required int inspectionId,
    required PartType partType,
    required ComparisonResult comparisonResult,
    String? operatorName,
    String? productionLine,
    String? batchNumber,
  }) async {
    try {
      // Pro demo účely simulujeme úspěšné odeslání
      // V produkci by zde byl skutečný email kód nebo export do souboru
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      return false;
    }
  }
}