import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/quality_report.dart';
import '../models/comparison_result.dart';
import '../models/defect.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'quality_control.db');
    
    return await openDatabase(
      path,
      version: 2, // Increased version for Enhanced Confidence System
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabulka inspections - hlavní záznamy kontrol
    await db.execute('''
      CREATE TABLE inspections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference_image_path TEXT NOT NULL,
        part_image_path TEXT NOT NULL,
        part_type TEXT NOT NULL CHECK(part_type IN ('VÝLISKY', 'OBRÁBĚNÉ')),
        created_at TEXT NOT NULL,
        overall_result TEXT NOT NULL CHECK(overall_result IN ('PASS', 'FAIL', 'WARNING')),
        confidence_score REAL NOT NULL,
        summary TEXT NOT NULL,
        gemini_response_json TEXT,
        operator_name TEXT,
        production_line TEXT,
        batch_number TEXT,
        part_serial TEXT
      )
    ''');

    // Tabulka defects - detailní defekty pro každou inspekci
    await db.execute('''
      CREATE TABLE defects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inspection_id INTEGER NOT NULL,
        defect_type TEXT NOT NULL,
        description TEXT NOT NULL,
        severity TEXT NOT NULL,
        location_x REAL NOT NULL,
        location_y REAL NOT NULL,
        location_width REAL NOT NULL,
        location_height REAL NOT NULL,
        confidence REAL NOT NULL,
        FOREIGN KEY (inspection_id) REFERENCES inspections (id) ON DELETE CASCADE
      )
    ''');

    // Tabulka email_reports - záznamy o odeslaných emailech
    await db.execute('''
      CREATE TABLE email_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inspection_id INTEGER NOT NULL,
        recipient_email TEXT NOT NULL,
        sent_at TEXT NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('SENT', 'FAILED', 'PENDING')),
        error_message TEXT,
        FOREIGN KEY (inspection_id) REFERENCES inspections (id) ON DELETE CASCADE
      )
    ''');

    // Indexy pro rychlejší vyhledávání
    await db.execute('CREATE INDEX idx_inspections_created_at ON inspections(created_at)');
    await db.execute('CREATE INDEX idx_inspections_part_type ON inspections(part_type)');
    await db.execute('CREATE INDEX idx_inspections_overall_result ON inspections(overall_result)');

    // Enhanced Analysis Records (version 2+)
    if (version >= 2) {
      await _createEnhancedAnalysisRecordsTable(db);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2 && newVersion >= 2) {
      // Migration to version 2: Add Enhanced Analysis Records
      await _createEnhancedAnalysisRecordsTable(db);
    }
  }

  Future<void> _createEnhancedAnalysisRecordsTable(Database db) async {
    // Tabulka enhanced_analysis_records - kompletní enhanced confidence system záznamy
    await db.execute('''
      CREATE TABLE enhanced_analysis_records (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        completed_at INTEGER,
        status TEXT NOT NULL CHECK(status IN ('initialized', 'qualityAnalyzed', 'confidenceCalculated', 'recommendationGenerated', 'aiAnalysisStarted', 'aiAnalysisCompleted', 'feedbackReceived', 'archived', 'failed')),
        user_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        reference_image_path TEXT NOT NULL,
        part_image_path TEXT NOT NULL,
        overall_confidence REAL,
        processing_time_ms INTEGER,
        tokens_used INTEGER,
        estimated_cost REAL,
        was_recommendation_followed INTEGER DEFAULT 0,
        record_data TEXT NOT NULL
      )
    ''');

    // Indexy pro enhanced analysis records
    await db.execute('CREATE INDEX idx_enhanced_records_created_at ON enhanced_analysis_records(created_at)');
    await db.execute('CREATE INDEX idx_enhanced_records_user_id ON enhanced_analysis_records(user_id)');
    await db.execute('CREATE INDEX idx_enhanced_records_status ON enhanced_analysis_records(status)');
    await db.execute('CREATE INDEX idx_enhanced_records_overall_confidence ON enhanced_analysis_records(overall_confidence)');
    await db.execute('CREATE INDEX idx_enhanced_records_session_id ON enhanced_analysis_records(session_id)');
  }

  // Uložení kompletní inspekce
  Future<int> saveInspection({
    required String referenceImagePath,
    required String partImagePath,
    required PartType partType,
    required ComparisonResult comparisonResult,
    String? operatorName,
    String? productionLine,
    String? batchNumber,
    String? partSerial,
  }) async {
    final db = await database;
    
    // Uložení hlavního záznamu
    final inspectionId = await db.insert('inspections', {
      'reference_image_path': referenceImagePath,
      'part_image_path': partImagePath,
      'part_type': partType == PartType.vylisky ? 'VÝLISKY' : 'OBRÁBĚNÉ',
      'created_at': DateTime.now().toIso8601String(),
      'overall_result': _mapQualityStatus(comparisonResult.overallQuality),
      'confidence_score': comparisonResult.confidenceScore,
      'summary': comparisonResult.summary,
      'gemini_response_json': jsonEncode(comparisonResult.toJson()),
      'operator_name': operatorName,
      'production_line': productionLine,
      'batch_number': batchNumber,
      'part_serial': partSerial,
    });

    // Uložení defektů
    for (final defect in comparisonResult.defectsFound) {
      await db.insert('defects', {
        'inspection_id': inspectionId,
        'defect_type': _mapDefectType(defect.type),
        'description': defect.description,
        'severity': _mapDefectSeverity(defect.severity),
        'location_x': defect.location.x,
        'location_y': defect.location.y,
        'location_width': defect.location.width,
        'location_height': defect.location.height,
        'confidence': defect.confidence,
      });
    }

    return inspectionId;
  }

  // Načtení všech inspekcí
  Future<List<QualityReport>> getAllInspections({int? limit}) async {
    final db = await database;
    
    final maps = await db.query(
      'inspections',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    List<QualityReport> reports = [];
    
    for (final map in maps) {
      final defects = await _getDefectsForInspection(map['id'] as int);
      final comparisonResult = ComparisonResult(
        overallQuality: _parseQualityStatus(map['overall_result'] as String),
        confidenceScore: map['confidence_score'] as double,
        defectsFound: defects,
        summary: map['summary'] as String,
      );

      reports.add(QualityReport.legacy(
        id: map['id'] as int,
        referenceImagePath: map['reference_image_path'] as String,
        partImagePath: map['part_image_path'] as String,
        partType: map['part_type'] == 'VÝLISKY' ? PartType.vylisky : PartType.obrabene,
        createdAt: DateTime.parse(map['created_at'] as String),
        comparisonResult: comparisonResult,
      ));
    }

    return reports;
  }

  // Načtení defektů pro konkrétní inspekci
  Future<List<Defect>> _getDefectsForInspection(int inspectionId) async {
    final db = await database;
    
    final maps = await db.query(
      'defects',
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
    );

    return maps.map((map) => Defect(
      type: _parseDefectType(map['defect_type'] as String),
      description: map['description'] as String,
      severity: _parseDefectSeverity(map['severity'] as String),
      location: DefectLocation(
        x: map['location_x'] as double,
        y: map['location_y'] as double,
        width: map['location_width'] as double,
        height: map['location_height'] as double,
      ),
      confidence: map['confidence'] as double,
    )).toList();
  }

  // Statistiky pro dashboard
  Future<Map<String, dynamic>> getStatistics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (fromDate != null && toDate != null) {
      whereClause = 'WHERE created_at BETWEEN ? AND ?';
      whereArgs = [fromDate.toIso8601String(), toDate.toIso8601String()];
    }

    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM inspections $whereClause',
      whereArgs,
    );

    final passResult = await db.rawQuery(
      'SELECT COUNT(*) as pass_count FROM inspections WHERE overall_result = "PASS" $whereClause',
      whereArgs.isEmpty ? [] : ['PASS', ...whereArgs.cast<String>()],
    );

    final failResult = await db.rawQuery(
      'SELECT COUNT(*) as fail_count FROM inspections WHERE overall_result = "FAIL" $whereClause',
      whereArgs.isEmpty ? [] : ['FAIL', ...whereArgs.cast<String>()],
    );

    final warningResult = await db.rawQuery(
      'SELECT COUNT(*) as warning_count FROM inspections WHERE overall_result = "WARNING" $whereClause',
      whereArgs.isEmpty ? [] : ['WARNING', ...whereArgs.cast<String>()],
    );

    return {
      'total_inspections': totalResult.first['total'],
      'pass_count': passResult.first['pass_count'],
      'fail_count': failResult.first['fail_count'],
      'warning_count': warningResult.first['warning_count'],
      'pass_rate': (totalResult.first['total'] as int) > 0 
          ? (passResult.first['pass_count'] as int) / (totalResult.first['total'] as int) * 100 
          : 0.0,
    };
  }

  // Export dat pro dataset
  Future<List<Map<String, dynamic>>> exportDatasetJson({
    PartType? partType,
    QualityStatus? resultFilter,
    int? limit,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (partType != null) {
      whereClause += whereClause.isEmpty ? 'WHERE ' : ' AND ';
      whereClause += 'part_type = ?';
      whereArgs.add(partType == PartType.vylisky ? 'VÝLISKY' : 'OBRÁBĚNÉ');
    }
    
    if (resultFilter != null) {
      whereClause += whereClause.isEmpty ? 'WHERE ' : ' AND ';
      whereClause += 'overall_result = ?';
      whereArgs.add(_mapQualityStatus(resultFilter));
    }

    final inspections = await db.query(
      'inspections',
      where: whereClause.isEmpty ? null : whereClause.substring(6), // Remove 'WHERE '
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    List<Map<String, dynamic>> dataset = [];
    
    for (final inspection in inspections) {
      final defects = await _getDefectsForInspection(inspection['id'] as int);
      
      dataset.add({
        'id': inspection['id'],
        'timestamp': inspection['created_at'],
        'part_type': inspection['part_type'],
        'reference_image': inspection['reference_image_path'],
        'part_image': inspection['part_image_path'],
        'result': inspection['overall_result'],
        'confidence': inspection['confidence_score'],
        'summary': inspection['summary'],
        'defects': defects.map((d) => {
          'type': _mapDefectType(d.type),
          'description': d.description,
          'severity': _mapDefectSeverity(d.severity),
          'location': {
            'x': d.location.x,
            'y': d.location.y,
            'width': d.location.width,
            'height': d.location.height,
          },
          'confidence': d.confidence,
        }).toList(),
        'metadata': {
          'operator': inspection['operator_name'],
          'production_line': inspection['production_line'],
          'batch_number': inspection['batch_number'],
          'part_serial': inspection['part_serial'],
        }
      });
    }

    return dataset;
  }

  // Záznam o odeslaném emailu
  Future<void> logEmailReport({
    required int inspectionId,
    required String recipientEmail,
    required String status,
    String? errorMessage,
  }) async {
    final db = await database;
    
    await db.insert('email_reports', {
      'inspection_id': inspectionId,
      'recipient_email': recipientEmail,
      'sent_at': DateTime.now().toIso8601String(),
      'status': status,
      'error_message': errorMessage,
    });
  }

  // Helper metody pro mapování enums
  String _mapQualityStatus(QualityStatus status) {
    switch (status) {
      case QualityStatus.pass: return 'PASS';
      case QualityStatus.fail: return 'FAIL';
      case QualityStatus.warning: return 'WARNING';
    }
  }

  QualityStatus _parseQualityStatus(String status) {
    switch (status) {
      case 'PASS': return QualityStatus.pass;
      case 'FAIL': return QualityStatus.fail;
      case 'WARNING': return QualityStatus.warning;
      default: throw ArgumentError('Unknown quality status: $status');
    }
  }

  String _mapDefectType(DefectType type) {
    switch (type) {
      case DefectType.missing: return 'MISSING';
      case DefectType.extra: return 'EXTRA';
      case DefectType.deformed: return 'DEFORMED';
      case DefectType.dimensional: return 'DIMENSIONAL';
    }
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

  String _mapDefectSeverity(DefectSeverity severity) {
    switch (severity) {
      case DefectSeverity.critical: return 'CRITICAL';
      case DefectSeverity.major: return 'MAJOR';
      case DefectSeverity.minor: return 'MINOR';
    }
  }

  DefectSeverity _parseDefectSeverity(String severity) {
    switch (severity) {
      case 'CRITICAL': return DefectSeverity.critical;
      case 'MAJOR': return DefectSeverity.major;
      case 'MINOR': return DefectSeverity.minor;
      default: throw ArgumentError('Unknown defect severity: $severity');
    }
  }
}