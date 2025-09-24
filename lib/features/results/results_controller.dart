import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/quality_report.dart';
import '../../core/models/comparison_result.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/email_service.dart';
import '../../core/services/dataset_export_service.dart';

class ResultsState {
  final int? savedInspectionId;
  final bool isSaving;
  final bool isEmailSending;
  final String? error;
  final String? successMessage;

  const ResultsState({
    this.savedInspectionId,
    this.isSaving = false,
    this.isEmailSending = false,
    this.error,
    this.successMessage,
  });

  ResultsState copyWith({
    int? savedInspectionId,
    bool? isSaving,
    bool? isEmailSending,
    String? error,
    String? successMessage,
  }) {
    return ResultsState(
      savedInspectionId: savedInspectionId ?? this.savedInspectionId,
      isSaving: isSaving ?? this.isSaving,
      isEmailSending: isEmailSending ?? this.isEmailSending,
      error: error,
      successMessage: successMessage,
    );
  }
}

class ResultsController extends StateNotifier<ResultsState> {
  final DatabaseHelper _databaseHelper;
  final EmailService _emailService;
  final DatasetExportService _datasetExportService;

  ResultsController(
    this._databaseHelper,
    this._emailService,
    this._datasetExportService,
  ) : super(const ResultsState());

  Future<void> autoSaveInspection({
    required String referenceImagePath,
    required String partImagePath,
    required PartType partType,
    required ComparisonResult comparisonResult,
    String? operatorName,
    String? productionLine,
  }) async {
    state = state.copyWith(isSaving: true, error: null);
    
    try {
      final inspectionId = await _databaseHelper.saveInspection(
        referenceImagePath: referenceImagePath,
        partImagePath: partImagePath,
        partType: partType,
        comparisonResult: comparisonResult,
        operatorName: operatorName,
        productionLine: productionLine,
        batchNumber: 'BATCH_${DateTime.now().millisecondsSinceEpoch}',
      );

      state = state.copyWith(
        savedInspectionId: inspectionId,
        isSaving: false,
        successMessage: 'Inspekce automaticky uložena',
      );
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Chyba při ukládání inspekce: $e',
      );
    }
  }

  Future<void> handleMenuAction(String action, {
    required ComparisonResult comparisonResult,
    required PartType partType,
    required String referenceImagePath,
    required String partImagePath,
  }) async {
    try {
      switch (action) {
        case 'send_report':
          await sendReport(
            comparisonResult: comparisonResult,
            partType: partType,
            referenceImagePath: referenceImagePath,
            partImagePath: partImagePath,
          );
          break;
        case 'save_report':
          await saveReport(comparisonResult: comparisonResult);
          break;
        case 'export_data':
          await exportToDataset(
            comparisonResult: comparisonResult,
            referenceImagePath: referenceImagePath,
            partImagePath: partImagePath,
            partType: partType,
          );
          break;
        default:
          state = state.copyWith(error: 'Neznámá akce: $action');
      }
    } catch (e) {
      state = state.copyWith(error: 'Chyba při provádění akce: $e');
    }
  }

  Future<void> sendReport({
    required ComparisonResult comparisonResult,
    required PartType partType,
    required String referenceImagePath,
    required String partImagePath,
  }) async {
    state = state.copyWith(isEmailSending: true, error: null);

    try {
      final qualityReport = QualityReport.fromComparisonResult(
        comparisonResult: comparisonResult,
        partType: partType,
        referenceImagePath: referenceImagePath,
        partImagePath: partImagePath,
        inspectionId: state.savedInspectionId ?? 0,
        timestamp: DateTime.now(),
        operatorName: 'System',
        productionLine: 'Auto',
        batchNumber: 'BATCH_${DateTime.now().millisecondsSinceEpoch}',
      );

      await _emailService.sendQualityReport(qualityReport);
      
      state = state.copyWith(
        isEmailSending: false,
        successMessage: 'Report byl úspěšně odeslán e-mailem',
      );
    } catch (e) {
      state = state.copyWith(
        isEmailSending: false,
        error: 'Chyba při odesílání e-mailu: $e',
      );
    }
  }

  Future<void> saveReport({required ComparisonResult comparisonResult}) async {
    state = state.copyWith(isSaving: true, error: null);

    try {
      // Zde by byla implementace uložení reportu do souboru
      await Future.delayed(const Duration(milliseconds: 500)); // Simulace
      
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Report byl úspěšně uložen',
      );
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Chyba při ukládání reportu: $e',
      );
    }
  }

  Future<void> exportToDataset({
    required ComparisonResult comparisonResult,
    required String referenceImagePath,
    required String partImagePath,
    required PartType partType,
  }) async {
    state = state.copyWith(isSaving: true, error: null);

    try {
      await _datasetExportService.exportComparisonResult(
        comparisonResult: comparisonResult,
        referenceImagePath: referenceImagePath,
        partImagePath: partImagePath,
        partType: partType,
      );
      
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Data byla úspěšně exportována do datasetu',
      );
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Chyba při exportu do datasetu: $e',
      );
    }
  }

  // Helper methods for UI state
  Color getStatusColor(QualityStatus status) {
    switch (status) {
      case QualityStatus.pass:
        return Colors.green;
      case QualityStatus.warning:
        return Colors.orange;
      case QualityStatus.fail:
        return Colors.red;
    }
  }

  IconData getStatusIcon(QualityStatus status) {
    switch (status) {
      case QualityStatus.pass:
        return Icons.check_circle;
      case QualityStatus.warning:
        return Icons.warning;
      case QualityStatus.fail:
        return Icons.error;
    }
  }

  String getStatusText(QualityStatus status) {
    switch (status) {
      case QualityStatus.pass:
        return 'SCHVÁLENO';
      case QualityStatus.warning:
        return 'VAROVÁNÍ';
      case QualityStatus.fail:
        return 'ZAMÍTNUTO';
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void clearSuccessMessage() {
    state = state.copyWith(successMessage: null);
  }
}

final resultsControllerProvider = StateNotifierProvider<ResultsController, ResultsState>((ref) {
  return ResultsController(
    DatabaseHelper(),
    ref.watch(emailServiceProvider),
    DatasetExportService(),
  );
});