import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/quality_report.dart';
import '../../core/models/comparison_result.dart';
import '../../core/services/gemini_service.dart';
// import '../../core/services/mock_gemini_service.dart';
import '../results/results_screen.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final PartType partType;
  final String referenceImagePath;
  final String partImagePath;

  const AnalysisScreen({
    super.key,
    required this.partType,
    required this.referenceImagePath,
    required this.partImagePath,
  });

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isAnalyzing = true;
  String _currentStep = 'Příprava analýzy...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _startAnalysis();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    try {
      setState(() {
        _currentStep = 'Načítání obrázků...';
        _progress = 0.2;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _currentStep = 'Odesílání do AI systému...';
        _progress = 0.4;
      });

      final geminiService = ref.read(geminiServiceProvider);
      
      setState(() {
        _currentStep = 'AI analýza probíhá...';
        _progress = 0.6;
      });

      final result = await geminiService.analyzeImages(
        referenceImage: File(widget.referenceImagePath),
        partImage: File(widget.partImagePath),
        partType: widget.partType,
      );

      setState(() {
        _currentStep = 'Dokončování...';
        _progress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              partType: widget.partType,
              referenceImagePath: widget.referenceImagePath,
              partImagePath: widget.partImagePath,
              comparisonResult: result,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _currentStep = 'Chyba při analýze: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Analýza'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isAnalyzing) ...[
              RotationTransition(
                turns: _animationController,
                child: const Icon(
                  Icons.analytics,
                  size: 80,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'AI analýza probíhá',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                _currentStep,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 10),
              Text('${(_progress * 100).round()}%'),
              const SizedBox(height: 40),
              const Text(
                'Gemini Vision API porovnává obrázky a identifikuje defekty',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Icon(
                Icons.error,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              const Text(
                'Chyba analýzy',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                _currentStep,
                style: const TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Zpět'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}