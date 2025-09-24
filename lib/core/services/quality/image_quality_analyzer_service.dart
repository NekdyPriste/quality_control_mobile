import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../models/quality/image_quality_metrics.dart';
import '../../models/quality/pre_analysis_result.dart';

class ImageQualityAnalyzerService {
  static const double _minAcceptableScore = 0.4;
  static const double _goodQualityScore = 0.7;
  
  // Váhy pro jednotlivé metriky při výpočtu celkového skóre
  static const Map<String, double> _metricWeights = {
    'sharpness': 0.25,      // Nejvyšší váha - ostrost je klíčová
    'brightness': 0.15,     // Střední váha
    'contrast': 0.20,       // Vysoká váha - kontrast ovlivní detekci
    'noiseLevel': 0.10,     // Nižší váha
    'resolution': 0.15,     // Střední váha
    'compression': 0.05,    // Nejnižší váha
    'objectCoverage': 0.10, // Nižší váha - není klíčové pro AI
  };

  Future<PreAnalysisResult> evaluateBeforeAIAnalysis({
    required File referenceImage,
    required File partImage,
  }) async {
    try {
      // Analyzuj kvalitu obou snímků paralelně
      final results = await Future.wait([
        analyzeImageQuality(referenceImage),
        analyzeImageQuality(partImage),
      ]);
      
      final refQuality = results[0];
      final partQuality = results[1];
      
      // Rozhodni na základě kvality snímků
      return _makePreAnalysisDecision(refQuality, partQuality);
      
    } catch (e) {
      // V případě chyby analýzy dovolíme pokračování s varováním
      return PreAnalysisResult.proceedWithWarning(
        expectedConfidence: 0.5,
        referenceQuality: ImageQualityMetrics.defaultMetrics(),
        partQuality: ImageQualityMetrics.defaultMetrics(),
        issues: [
          QualityIssue.blur(severity: IssueSeverity.major),
        ],
        recommendations: [
          'Nepodařilo se analyzovat kvalitu snímků',
          'Doporučujeme ruční kontrolu kvality před pokračováním',
        ],
      );
    }
  }

  Future<ImageQualityMetrics> analyzeImageQuality(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    
    if (image == null) {
      throw Exception('Nepodařilo se dekódovat obrázek: ${imageFile.path}');
    }

    // Paralelní výpočet všech metrik
    final futures = <Future<double>>[
      _calculateSharpness(image),
      _calculateBrightness(image),
      _calculateContrast(image),
      _calculateNoiseLevel(image),
      _calculateResolution(image),
      _calculateCompressionQuality(imageBytes),
      _calculateObjectCoverage(image),
    ];

    final metrics = await Future.wait(futures);
    final edgeClarity = await _calculateEdgeClarity(image);

    final sharpness = metrics[0];
    final brightness = metrics[1];
    final contrast = metrics[2];
    final noiseLevel = metrics[3];
    final resolution = metrics[4];
    final compression = metrics[5];
    final objectCoverage = metrics[6];

    // Výpočet celkového skóre pomocí vážených průměrů
    final overallScore = _calculateOverallScore({
      'sharpness': sharpness,
      'brightness': brightness,
      'contrast': contrast,
      'noiseLevel': 1.0 - noiseLevel, // Invertujeme - nižší šum = vyšší skóre
      'resolution': resolution,
      'compression': compression,
      'objectCoverage': objectCoverage,
    });

    return ImageQualityMetrics(
      sharpness: sharpness,
      brightness: brightness,
      contrast: contrast,
      noiseLevel: noiseLevel,
      resolution: resolution,
      compression: compression,
      objectCoverage: objectCoverage,
      edgeClarity: edgeClarity,
      overallScore: overallScore,
    );
  }

  // Výpočet ostrosti pomocí Laplacian variance
  Future<double> _calculateSharpness(img.Image image) async {
    final gray = img.grayscale(image);
    double variance = 0.0;
    int count = 0;

    // Laplacian kernel
    const kernel = [
      [0, -1, 0],
      [-1, 4, -1],
      [0, -1, 0]
    ];

    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        double sum = 0.0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = gray.getPixel(x + kx, y + ky);
            final intensity = img.getLuminance(pixel) / 255.0;
            sum += intensity * kernel[ky + 1][kx + 1];
          }
        }
        variance += sum * sum;
        count++;
      }
    }

    final result = count > 0 ? variance / count : 0.0;
    return (result * 1000).clamp(0.0, 1.0); // Normalizace
  }

  // Výpočet jasu pomocí histogram analýzy
  Future<double> _calculateBrightness(img.Image image) async {
    double totalBrightness = 0.0;
    final pixelCount = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = img.getLuminance(pixel) / 255.0;
        totalBrightness += brightness;
      }
    }

    return totalBrightness / pixelCount;
  }

  // Výpočet kontrastu pomocí RMS kontrastu
  Future<double> _calculateContrast(img.Image image) async {
    final brightness = await _calculateBrightness(image);
    double sumSquaredDiff = 0.0;
    final pixelCount = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final pixelBrightness = img.getLuminance(pixel) / 255.0;
        final diff = pixelBrightness - brightness;
        sumSquaredDiff += diff * diff;
      }
    }

    final rmsContrast = sqrt(sumSquaredDiff / pixelCount);
    return rmsContrast.clamp(0.0, 1.0);
  }

  // Výpočet úrovně šumu pomocí statistické analýzy
  Future<double> _calculateNoiseLevel(img.Image image) async {
    final gray = img.grayscale(image);
    double noiseVariance = 0.0;
    int count = 0;

    // Použijeme malý kernel pro detekci lokálních variací
    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        final centerPixel = img.getLuminance(gray.getPixel(x, y)) / 255.0;
        double localVariance = 0.0;
        
        // 3x3 okolí
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final neighborPixel = img.getLuminance(gray.getPixel(x + dx, y + dy)) / 255.0;
            final diff = neighborPixel - centerPixel;
            localVariance += diff * diff;
          }
        }
        
        noiseVariance += localVariance / 8; // 8 sousedů
        count++;
      }
    }

    final avgNoise = count > 0 ? noiseVariance / count : 0.0;
    return (avgNoise * 10).clamp(0.0, 1.0); // Normalizace a škálování
  }

  // Výpočet kvality rozlišení
  Future<double> _calculateResolution(img.Image image) async {
    final pixelCount = image.width * image.height;
    
    // Referenční hodnoty (upravit podle požadavků aplikace)
    const minResolution = 640 * 480;      // VGA
    const goodResolution = 1920 * 1080;   // Full HD
    
    if (pixelCount < minResolution) {
      return (pixelCount / minResolution).clamp(0.0, 1.0);
    } else if (pixelCount >= goodResolution) {
      return 1.0;
    } else {
      // Lineární interpolace mezi min a good rozlišením
      final ratio = (pixelCount - minResolution) / (goodResolution - minResolution);
      return (0.5 + ratio * 0.5).clamp(0.0, 1.0);
    }
  }

  // Výpočet kvality komprese (detekce JPEG artefaktů)
  Future<double> _calculateCompressionQuality(Uint8List imageBytes) async {
    final fileSize = imageBytes.length;
    
    // Odhad kvality na základě velikosti souboru vs rozlišení
    // Větší soubor při stejném rozlišení = méně komprese = vyšší kvalita
    final sizePerPixelKB = fileSize / 1024.0; // Zjednodušený výpočet
    
    // Normalizace - očekáváme 50-500 KB pro typické snímky
    final quality = (sizePerPixelKB / 500.0).clamp(0.0, 1.0);
    
    return quality;
  }

  // Výpočet pokrytí objektu na snímku
  Future<double> _calculateObjectCoverage(img.Image image) async {
    // Zjednodušená detekce objektu pomocí edge detection
    final edges = await _calculateEdgeClarity(image);
    
    // Odhadneme pokrytí objektu na základě množství hran
    // Více hran = větší objekt = lepší pokrytí
    return (edges * 2.0).clamp(0.0, 1.0);
  }

  // Výpočet jasnosti hran (edge clarity)
  Future<double> _calculateEdgeClarity(img.Image image) async {
    final gray = img.grayscale(image);
    double totalEdgeStrength = 0.0;
    int edgeCount = 0;

    // Sobel operator pro detekci hran
    const sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1]
    ];
    
    const sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1]
    ];

    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        double gx = 0.0, gy = 0.0;
        
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = gray.getPixel(x + kx, y + ky);
            final intensity = img.getLuminance(pixel) / 255.0;
            gx += intensity * sobelX[ky + 1][kx + 1];
            gy += intensity * sobelY[ky + 1][kx + 1];
          }
        }
        
        final magnitude = sqrt(gx * gx + gy * gy);
        totalEdgeStrength += magnitude;
        edgeCount++;
      }
    }

    final avgEdgeStrength = edgeCount > 0 ? totalEdgeStrength / edgeCount : 0.0;
    return (avgEdgeStrength * 4).clamp(0.0, 1.0); // Normalizace
  }

  // Výpočet celkového skóre pomocí vážených průměrů
  double _calculateOverallScore(Map<String, double> metrics) {
    double weightedSum = 0.0;
    double totalWeight = 0.0;

    for (final entry in metrics.entries) {
      final weight = _metricWeights[entry.key] ?? 0.0;
      weightedSum += entry.value * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? weightedSum / totalWeight : 0.0;
  }

  // Rozhodovací logika pro pre-analysis
  PreAnalysisResult _makePreAnalysisDecision(
    ImageQualityMetrics refQuality,
    ImageQualityMetrics partQuality,
  ) {
    final minQuality = min(refQuality.overallScore, partQuality.overallScore);
    final avgQuality = (refQuality.overallScore + partQuality.overallScore) / 2;
    
    final allIssues = <QualityIssue>[
      ...refQuality.getQualityIssues(),
      ...partQuality.getQualityIssues(),
    ];

    final criticalIssues = allIssues
        .where((issue) => issue.severity == IssueSeverity.critical)
        .toList();

    // KRITICKY ŠPATNÁ KVALITA - UŠETŘI 100% TOKENŮ
    if (minQuality < 0.3 || criticalIssues.length >= 2) {
      return PreAnalysisResult.reject(
        reason: 'Kriticky nízká kvalita snímků - analýza by byla nespolehlivá',
        recommendations: _generateCriticalRecommendations(allIssues),
        referenceQuality: refQuality,
        partQuality: partQuality,
        issues: allIssues,
        savedTokens: 200, // Odhadovaná úspora tokenů
      );
    }

    // ŠPATNÁ KVALITA - UŠETŘI TOKENY optimalizací
    if (minQuality < _minAcceptableScore) {
      return PreAnalysisResult.optimizeFirst(
        expectedConfidence: minQuality * 0.7, // Snížená očekávaná jistota
        referenceQuality: refQuality,
        partQuality: partQuality,
        issues: allIssues,
        recommendations: _generateOptimizationRecommendations(allIssues),
      );
    }

    // STŘEDNÍ KVALITA - POKRAČUJ S VAROVÁNÍM
    if (avgQuality < _goodQualityScore) {
      return PreAnalysisResult.proceedWithWarning(
        expectedConfidence: avgQuality * 0.85,
        referenceQuality: refQuality,
        partQuality: partQuality,
        issues: allIssues,
        recommendations: _generateWarningRecommendations(allIssues),
      );
    }

    // DOBRÁ KVALITA - POKRAČUJ BEZ VAROVÁNÍ
    return PreAnalysisResult.proceed(
      expectedConfidence: avgQuality * 0.95,
      referenceQuality: refQuality,
      partQuality: partQuality,
      issues: allIssues,
    );
  }

  List<String> _generateCriticalRecommendations(List<QualityIssue> issues) {
    final recommendations = <String>[];
    
    if (issues.any((i) => i.type == QualityIssueType.blur)) {
      recommendations.addAll([
        'Vyčistěte objektiv kamery',
        'Použijte stativ nebo stabilizujte ruce',
        'Aktivujte autofocus před pořízením snímku',
      ]);
    }
    
    if (issues.any((i) => i.type == QualityIssueType.lighting)) {
      recommendations.addAll([
        'Zlepšete osvětlení - použijte dodatečné světlo',
        'Vyhněte se přímému slunečnímu světlu',
        'Odstraňte stíny z objektu',
      ]);
    }
    
    recommendations.add('Pokračování v analýze by vedlo k nespolehlivým výsledkům');
    return recommendations;
  }

  List<String> _generateOptimizationRecommendations(List<QualityIssue> issues) {
    final recommendations = <String>[];
    
    recommendations.add('Můžeme pokračovat s omezenou přesností nebo:');
    
    for (final issue in issues) {
      recommendations.addAll(issue.recommendations);
    }
    
    return recommendations;
  }

  List<String> _generateWarningRecommendations(List<QualityIssue> issues) {
    final recommendations = <String>['Kvalita snímků je přijatelná, ale můžete zlepšit:'];
    
    for (final issue in issues.take(3)) { // Pouze top 3 doporučení
      if (issue.recommendations.isNotEmpty) {
        recommendations.add('• ${issue.recommendations.first}');
      }
    }
    
    return recommendations;
  }
}

extension on ImageQualityMetrics {
  static ImageQualityMetrics defaultMetrics() => const ImageQualityMetrics(
    sharpness: 0.5,
    brightness: 0.5,
    contrast: 0.5,
    noiseLevel: 0.5,
    resolution: 0.5,
    compression: 0.5,
    objectCoverage: 0.5,
    edgeClarity: 0.5,
    overallScore: 0.5,
  );
}