import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/batch_analysis.dart';
import '../../core/models/quality_report.dart';
import '../../core/services/batch_analysis_service.dart';
import '../../core/services/background_batch_service.dart';
import '../../core/services/email_service.dart';

enum BatchProcessingType { background, foreground }

class BatchAnalysisState {
  final List<BatchPhotoPair> photoPairs;
  final String operatorName;
  final String productionLine;
  final String batchNumber;
  final bool isLoading;
  final bool isProcessing;
  final String? error;
  final String? successMessage;
  final BatchAnalysisJob? currentJob;

  const BatchAnalysisState({
    this.photoPairs = const [],
    this.operatorName = '',
    this.productionLine = '',
    this.batchNumber = '',
    this.isLoading = false,
    this.isProcessing = false,
    this.error,
    this.successMessage,
    this.currentJob,
  });

  BatchAnalysisState copyWith({
    List<BatchPhotoPair>? photoPairs,
    String? operatorName,
    String? productionLine,
    String? batchNumber,
    bool? isLoading,
    bool? isProcessing,
    String? error,
    String? successMessage,
    BatchAnalysisJob? currentJob,
  }) {
    return BatchAnalysisState(
      photoPairs: photoPairs ?? this.photoPairs,
      operatorName: operatorName ?? this.operatorName,
      productionLine: productionLine ?? this.productionLine,
      batchNumber: batchNumber ?? this.batchNumber,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      successMessage: successMessage,
      currentJob: currentJob ?? this.currentJob,
    );
  }
}

class BatchAnalysisController extends StateNotifier<BatchAnalysisState> {
  final BatchAnalysisService _batchAnalysisService;
  final EmailService _emailService;

  BatchAnalysisController(
    this._batchAnalysisService,
    this._emailService,
  ) : super(const BatchAnalysisState());

  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final operatorName = prefs.getString('operator_name') ?? '';
      final productionLine = prefs.getString('production_line') ?? '';
      
      state = state.copyWith(
        operatorName: operatorName,
        productionLine: productionLine,
        batchNumber: 'BATCH_${DateTime.now().millisecondsSinceEpoch}',
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Chyba při načítání nastavení: $e',
      );
    }
  }

  void addPhotoPair(BatchPhotoPair photoPair) {
    final updatedPairs = List<BatchPhotoPair>.from(state.photoPairs)
      ..add(photoPair);
    
    state = state.copyWith(
      photoPairs: updatedPairs,
      error: null,
    );
  }

  void removePhotoPair(String pairId) {
    final updatedPairs = state.photoPairs
        .where((pair) => pair.id != pairId)
        .toList();
    
    state = state.copyWith(
      photoPairs: updatedPairs,
      error: null,
    );
  }

  void updateOperatorName(String name) {
    state = state.copyWith(operatorName: name, error: null);
  }

  void updateProductionLine(String line) {
    state = state.copyWith(productionLine: line, error: null);
  }

  void updateBatchNumber(String number) {
    state = state.copyWith(batchNumber: number, error: null);
  }

  Future<void> startBatchAnalysis(BatchProcessingType processingType) async {
    if (state.photoPairs.isEmpty) {
      state = state.copyWith(error: 'Nejsou vybrány žádné fotografie');
      return;
    }

    if (state.operatorName.trim().isEmpty) {
      state = state.copyWith(error: 'Zadejte jméno operátora');
      return;
    }

    if (state.productionLine.trim().isEmpty) {
      state = state.copyWith(error: 'Zadejte výrobní linku');
      return;
    }

    switch (processingType) {
      case BatchProcessingType.background:
        await _startBackgroundBatchAnalysis();
        break;
      case BatchProcessingType.foreground:
        await _startForegroundBatchAnalysis();
        break;
    }
  }

  Future<void> _startBackgroundBatchAnalysis() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (kIsWeb) {
        state = state.copyWith(
          isLoading: false,
          error: 'Background analýza není podporována na webu',
        );
        return;
      }

      final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';
      final jobData = {
        'name': 'Batch ${state.batchNumber}',
        'operatorName': state.operatorName,
        'productionLine': state.productionLine,
        'batchNumber': state.batchNumber,
      };

      await BackgroundBatchService.scheduleBatchAnalysis(
        jobId: jobId,
        photoPairs: state.photoPairs,
        jobData: jobData,
      );

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Background analýza byla naplánována',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Chyba při plánování background analýzy: $e',
      );
    }
  }

  Future<void> _startForegroundBatchAnalysis() async {
    state = state.copyWith(isProcessing: true, error: null);

    try {
      final job = BatchAnalysisJob(
        id: 'fg_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Batch ${state.batchNumber}',
        photoPairs: state.photoPairs,
        status: BatchStatus.processing,
        createdAt: DateTime.now(),
        totalPairs: state.photoPairs.length,
        operatorName: state.operatorName,
        productionLine: state.productionLine,
        batchNumber: state.batchNumber,
      );

      final completedJob = await _batchAnalysisService.processBatch(job);
      
      state = state.copyWith(
        isProcessing: false,
        currentJob: completedJob,
        successMessage: 'Batch analýza dokončena',
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Chyba při zpracování batch analýzy: $e',
      );
    }
  }

  Future<void> sendReport(BatchAnalysisJob job) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final reportContent = _generateReportContent(job);
      
      // Vytvoření dummy QualityReport pro EmailService
      final dummyReport = QualityReport(
        id: job.id,
        inspectionId: 0,
        partType: PartType.housing, // Default hodnota
        referenceImagePath: '',
        partImagePath: '',
        overallQuality: job.passCount > job.failCount 
            ? QualityStatus.pass 
            : QualityStatus.fail,
        timestamp: job.createdAt,
        summary: reportContent,
        defectsFound: [],
        operatorName: job.operatorName ?? 'N/A',
        productionLine: job.productionLine ?? 'N/A',
        batchNumber: job.batchNumber ?? 'N/A',
        criticalDefects: 0,
        majorDefects: 0,
        minorDefects: 0,
      );

      await _emailService.sendQualityReport(dummyReport);
      
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Report byl úspěšně odeslán e-mailem',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Chyba při odesílání reportu: $e',
      );
    }
  }

  String _generateReportContent(BatchAnalysisJob job) {
    final buffer = StringBuffer();
    buffer.writeln('=== BATCH ANALÝZA REPORT ===\n');
    buffer.writeln('Název úlohy: ${job.name}');
    buffer.writeln('Batch číslo: ${job.batchNumber}');
    buffer.writeln('Operátor: ${job.operatorName}');
    buffer.writeln('Výrobní linka: ${job.productionLine}');
    buffer.writeln('Vytvořeno: ${job.createdAt}');
    buffer.writeln('Status: ${job.status.name}\n');
    
    buffer.writeln('=== STATISTIKY ===');
    buffer.writeln('Celkem páů: ${job.totalPairs}');
    buffer.writeln('Dokončeno: ${job.completedCount}');
    buffer.writeln('Prošlo: ${job.passCount}');
    buffer.writeln('Neprošlo: ${job.failCount}');
    buffer.writeln('Varování: ${job.warningCount}');
    
    final successRate = job.totalPairs > 0 
        ? ((job.passCount / job.totalPairs) * 100).toStringAsFixed(1)
        : '0.0';
    buffer.writeln('Úspěšnost: $successRate%\n');
    
    buffer.writeln('=== ZÁVĚR ===');
    if (job.passCount > job.failCount) {
      buffer.writeln('✅ Batch prošel kontrolou kvality');
    } else {
      buffer.writeln('❌ Batch neprošel kontrolou kvality');
    }
    
    return buffer.toString();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void clearSuccessMessage() {
    state = state.copyWith(successMessage: null);
  }

  void clearCurrentJob() {
    state = state.copyWith(currentJob: null);
  }
}

final batchAnalysisControllerProvider = StateNotifierProvider<BatchAnalysisController, BatchAnalysisState>((ref) {
  return BatchAnalysisController(
    ref.watch(batchAnalysisServiceProvider),
    ref.watch(emailServiceProvider),
  );
});