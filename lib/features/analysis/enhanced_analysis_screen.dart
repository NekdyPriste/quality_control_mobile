import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/quality_report.dart';
import '../../core/models/comparison_result.dart';
import '../../core/models/quality/enhanced_confidence_score.dart';
import '../../core/models/quality/action_recommendation.dart';
import '../../core/models/quality/pre_analysis_result.dart';
import '../../core/services/quality/enhanced_gemini_service.dart';
import '../results/enhanced_results_screen.dart';

class EnhancedAnalysisScreen extends ConsumerStatefulWidget {
  final PartType partType;
  final String referenceImagePath;
  final String partImagePath;
  final String userId;
  final AnalysisComplexity complexity;

  const EnhancedAnalysisScreen({
    super.key,
    required this.partType,
    required this.referenceImagePath,
    required this.partImagePath,
    required this.userId,
    this.complexity = AnalysisComplexity.moderate,
  });

  @override
  ConsumerState<EnhancedAnalysisScreen> createState() => _EnhancedAnalysisScreenState();
}

class _EnhancedAnalysisScreenState extends ConsumerState<EnhancedAnalysisScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _progressController;
  
  bool _isAnalyzing = true;
  String _currentStep = 'Inicializace...';
  String _currentPhase = 'PŘÍPRAVA';
  double _progress = 0.0;
  int _estimatedTokensSaved = 0;
  bool _showRecommendation = false;
  ActionRecommendation? _currentRecommendation;
  PreAnalysisResult? _preAnalysisResult;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _startEnhancedAnalysis();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _startEnhancedAnalysis() async {
    try {
      final enhancedService = ref.read(enhancedGeminiServiceProvider);

      // Phase 1: Image Quality Analysis
      await _updateProgress('ANALÝZA KVALITY', 'Hodnocení kvality snímků...', 0.1);
      await Future.delayed(const Duration(milliseconds: 300));

      await _updateProgress('ANALÝZA KVALITY', 'Kontrola ostrosti a osvětlení...', 0.2);
      await Future.delayed(const Duration(milliseconds: 500));

      await _updateProgress('ANALÝZA KVALITY', 'Výpočet confidence skóre...', 0.3);
      await Future.delayed(const Duration(milliseconds: 300));

      // Start the actual analysis
      final result = await enhancedService.performEnhancedAnalysis(
        referenceImage: File(widget.referenceImagePath),
        partImage: File(widget.partImagePath),
        partType: widget.partType,
        userId: widget.userId,
        complexity: widget.complexity,
      );

      await _handleAnalysisResult(result);

    } catch (e) {
      await _handleAnalysisError(e);
    }
  }

  Future<void> _handleAnalysisResult(EnhancedAnalysisResult result) async {
    setState(() {
      _preAnalysisResult = result.preAnalysisResult;
      _estimatedTokensSaved = result.tokensSaved ?? 0;
    });

    switch (result.decision) {
      case AnalysisDecision.retakeRequired:
        await _handleRetakeRequired(result);
        break;
        
      case AnalysisDecision.optimizeFirst:
        await _handleOptimizeFirst(result);
        break;
        
      case AnalysisDecision.analysisCompleted:
        await _handleAnalysisCompleted(result);
        break;
    }
  }

  Future<void> _handleRetakeRequired(EnhancedAnalysisResult result) async {
    await _updateProgress('DOPORUČENÍ', 'Kvalita snímků nevyhovuje standardům', 0.5);
    
    setState(() {
      _currentRecommendation = result.recommendation;
      _showRecommendation = true;
    });

    // Show recommendation for 3 seconds, then navigate
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      _navigateToRecommendations(result);
    }
  }

  Future<void> _handleOptimizeFirst(EnhancedAnalysisResult result) async {
    await _updateProgress('OPTIMALIZACE', 'Doporučeny úpravy podmínek', 0.6);
    
    setState(() {
      _currentRecommendation = result.recommendation;
      _showRecommendation = true;
    });

    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      _navigateToOptimization(result);
    }
  }

  Future<void> _handleAnalysisCompleted(EnhancedAnalysisResult result) async {
    // Phase 2: AI Analysis Completed
    await _updateProgress('AI ANALÝZA', 'Analýza dokončena úspěšně', 0.7);
    await Future.delayed(const Duration(milliseconds: 500));

    // Phase 3: Confidence Calculation
    await _updateProgress('CONFIDENCE', 'Výpočet finální jistoty...', 0.9);
    await Future.delayed(const Duration(milliseconds: 500));

    await _updateProgress('DOKONČENO', 'Analýza dokončena', 1.0);
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      _navigateToResults(result);
    }
  }

  Future<void> _handleAnalysisError(dynamic error) async {
    await _updateProgress('CHYBA', 'Chyba při analýze: $error', 0.0);
    
    setState(() {
      _isAnalyzing = false;
    });

    // Show retry option after error
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      _showErrorDialog(error.toString());
    }
  }

  Future<void> _updateProgress(String phase, String step, double progress) async {
    setState(() {
      _currentPhase = phase;
      _currentStep = step;
      _progress = progress;
    });
    
    _progressController.animateTo(progress);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  void _navigateToRecommendations(EnhancedAnalysisResult result) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RecommendationScreen(
          result: result,
          onRetakeImages: () => _retakeImages(),
        ),
      ),
    );
  }

  void _navigateToOptimization(EnhancedAnalysisResult result) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OptimizationScreen(
          result: result,
          onOptimizationComplete: () => _continueWithOptimizedAnalysis(result),
        ),
      ),
    );
  }

  void _navigateToResults(EnhancedAnalysisResult result) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedResultsScreen(
          result: result,
          partType: widget.partType,
          referenceImagePath: widget.referenceImagePath,
          partImagePath: widget.partImagePath,
        ),
      ),
    );
  }

  void _retakeImages() {
    Navigator.pop(context); // Go back to image capture
  }

  void _continueWithOptimizedAnalysis(EnhancedAnalysisResult result) {
    // Mark recommendation as followed and continue
    final enhancedService = ref.read(enhancedGeminiServiceProvider);
    enhancedService.markRecommendationFollowed(result.recordId);
    
    // Continue with analysis (could restart or proceed based on optimization)
    _startEnhancedAnalysis();
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chyba analýzy'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to capture
            },
            child: const Text('Zpět'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startEnhancedAnalysis(); // Retry
            },
            child: const Text('Zkusit znovu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Enhanced AI Analýza'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Progress Header
              _buildProgressHeader(),
              
              const SizedBox(height: 40),
              
              // Main Analysis Animation
              Expanded(
                child: _showRecommendation
                    ? _buildRecommendationView()
                    : _buildAnalysisView(),
              ),
              
              // Progress Bar
              _buildProgressBar(),
              
              const SizedBox(height: 20),
              
              // Status Text
              _buildStatusText(),
              
              // Token Savings Display
              if (_estimatedTokensSaved > 0)
                _buildTokenSavingsDisplay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getPhaseIcon(_currentPhase),
            color: Colors.blue.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _currentPhase,
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated Analysis Icon
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _animationController.value * 2 * 3.14159,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade400,
                      Colors.purple.shade400,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 40),
        
        // Analysis Title
        Text(
          'Enhanced AI Analýza',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 16),
        
        Text(
          'Pokročilá analýza s kontrolou kvality a confidence scoring',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRecommendationView() {
    if (_currentRecommendation == null) return const SizedBox();
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _getRecommendationIcon(_currentRecommendation!.type),
          size: 80,
          color: _getRecommendationColor(_currentRecommendation!.priority),
        ),
        
        const SizedBox(height: 24),
        
        Text(
          _currentRecommendation!.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 12),
        
        Text(
          _currentRecommendation!.description,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 20),
        
        if (_currentRecommendation!.steps.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Doporučené kroky:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...(_currentRecommendation!.steps.take(3).map((step) => 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('${step.order}. ${step.action}'),
                  )
                )),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Postup',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(_progress * 100).round()}%',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) {
            return LinearProgressIndicator(
              value: _progressController.value,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _progress == 1.0 ? Colors.green : Colors.blue,
              ),
              minHeight: 6,
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusText() {
    return Text(
      _currentStep,
      style: TextStyle(
        fontSize: 16,
        color: Colors.grey[700],
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildTokenSavingsDisplay() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.savings,
            color: Colors.green.shade600,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            'Ušetřeno $_estimatedTokensSaved tokenů',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPhaseIcon(String phase) {
    switch (phase) {
      case 'PŘÍPRAVA': return Icons.settings;
      case 'ANALÝZA KVALITY': return Icons.image_search;
      case 'AI ANALÝZA': return Icons.psychology;
      case 'CONFIDENCE': return Icons.verified;
      case 'DOPORUČENÍ': return Icons.recommend;
      case 'OPTIMALIZACE': return Icons.tune;
      case 'DOKONČENO': return Icons.check_circle;
      case 'CHYBA': return Icons.error;
      default: return Icons.autorenew;
    }
  }

  IconData _getRecommendationIcon(RecommendationType type) {
    switch (type) {
      case RecommendationType.retakePhoto: return Icons.camera_alt;
      case RecommendationType.improveConditions: return Icons.wb_incandescent;
      case RecommendationType.adjustSettings: return Icons.settings;
      case RecommendationType.changeBackground: return Icons.backdrop;
      case RecommendationType.repositionCamera: return Icons.center_focus_strong;
      case RecommendationType.reviewSettings: return Icons.checklist;
      case RecommendationType.proceed: return Icons.play_arrow;
    }
  }

  Color _getRecommendationColor(ActionPriority priority) {
    switch (priority) {
      case ActionPriority.critical: return Colors.red;
      case ActionPriority.high: return Colors.orange;
      case ActionPriority.medium: return Colors.blue;
      case ActionPriority.low: return Colors.green;
    }
  }
}

// Placeholder screens that would need to be implemented
class RecommendationScreen extends StatelessWidget {
  final EnhancedAnalysisResult result;
  final VoidCallback onRetakeImages;

  const RecommendationScreen({
    super.key,
    required this.result,
    required this.onRetakeImages,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doporučení')),
      body: const Center(child: Text('Recommendation Screen - To be implemented')),
    );
  }
}

class OptimizationScreen extends StatelessWidget {
  final EnhancedAnalysisResult result;
  final VoidCallback onOptimizationComplete;

  const OptimizationScreen({
    super.key,
    required this.result,
    required this.onOptimizationComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Optimalizace')),
      body: const Center(child: Text('Optimization Screen - To be implemented')),
    );
  }
}

class EnhancedResultsScreen extends StatelessWidget {
  final EnhancedAnalysisResult result;
  final PartType partType;
  final String referenceImagePath;
  final String partImagePath;

  const EnhancedResultsScreen({
    super.key,
    required this.result,
    required this.partType,
    required this.referenceImagePath,
    required this.partImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Výsledky Enhanced Analýzy')),
      body: const Center(child: Text('Enhanced Results Screen - To be implemented')),
    );
  }
}