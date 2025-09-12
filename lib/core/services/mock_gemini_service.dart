import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comparison_result.dart';
import '../models/defect.dart';
import '../models/quality_report.dart';

final mockGeminiServiceProvider = Provider<MockGeminiService>((ref) {
  return MockGeminiService();
});

class MockGeminiService {
  final Random _random = Random();

  Future<ComparisonResult> analyzeImages({
    required File? referenceImage,
    required File? partImage,
    required PartType partType,
    String? referenceImagePath,
    String? partImagePath,
  }) async {
    // Simulace času API volání
    await Future.delayed(Duration(seconds: 2 + _random.nextInt(3)));

    // Generuj různé výsledky pro demonstraci
    final scenarios = [
      _generatePassResult(partType),
      _generateWarningResult(partType),
      _generateFailResult(partType),
    ];

    return scenarios[_random.nextInt(scenarios.length)];
  }

  ComparisonResult _generatePassResult(PartType partType) {
    return ComparisonResult(
      overallQuality: QualityStatus.pass,
      confidenceScore: 0.92 + _random.nextDouble() * 0.07,
      defectsFound: _random.nextBool() 
          ? [] 
          : [
              Defect(
                type: DefectType.dimensional,
                description: 'Mírná rozměrová odchylka v toleranci',
                severity: DefectSeverity.minor,
                location: _generateRandomLocation(),
                confidence: 0.75 + _random.nextDouble() * 0.2,
              ),
            ],
      summary: partType == PartType.vylisky
          ? 'Výlisek vyhovuje všem specifikacím. Kvalita odpovídá požadavkům.'
          : 'Obráběný díl splňuje všechny rozměrové tolerance. Povrchová úprava je v pořádku.',
    );
  }

  ComparisonResult _generateWarningResult(PartType partType) {
    return ComparisonResult(
      overallQuality: QualityStatus.warning,
      confidenceScore: 0.78 + _random.nextDouble() * 0.15,
      defectsFound: [
        Defect(
          type: DefectType.dimensional,
          description: 'Rozměrová odchylka blízko horní toleranční meze',
          severity: DefectSeverity.major,
          location: _generateRandomLocation(),
          confidence: 0.85 + _random.nextDouble() * 0.1,
        ),
        if (_random.nextBool())
          Defect(
            type: DefectType.deformed,
            description: 'Mírná deformace v oblasti spojení',
            severity: DefectSeverity.minor,
            location: _generateRandomLocation(),
            confidence: 0.72 + _random.nextDouble() * 0.2,
          ),
      ],
      summary: partType == PartType.vylisky
          ? 'Výlisek vykazuje některé odchylky, které vyžadují pozornost. Doporučuje se kontrola výrobního procesu.'
          : 'Obráběný díl má rozměrové odchylky blízko mezních hodnot. Doporučuje se přenastavení obráběcího stroje.',
    );
  }

  ComparisonResult _generateFailResult(PartType partType) {
    final defects = <Defect>[
      Defect(
        type: DefectType.missing,
        description: 'Chybějící otvor Ø8mm',
        severity: DefectSeverity.critical,
        location: _generateRandomLocation(),
        confidence: 0.95 + _random.nextDouble() * 0.04,
      ),
      Defect(
        type: DefectType.extra,
        description: 'Přebývající materiál - otřep',
        severity: DefectSeverity.major,
        location: _generateRandomLocation(),
        confidence: 0.88 + _random.nextDouble() * 0.1,
      ),
    ];

    if (_random.nextBool()) {
      defects.add(
        Defect(
          type: DefectType.deformed,
          description: 'Značná deformace tvaru',
          severity: DefectSeverity.critical,
          location: _generateRandomLocation(),
          confidence: 0.91 + _random.nextDouble() * 0.08,
        ),
      );
    }

    return ComparisonResult(
      overallQuality: QualityStatus.fail,
      confidenceScore: 0.65 + _random.nextDouble() * 0.25,
      defectsFound: defects,
      summary: partType == PartType.vylisky
          ? 'Výlisek NEVYHOVUJE specifikacím. Zjištěny kritické defekty vyžadující zastavení výroby a analýzu příčin.'
          : 'Obráběný díl NEVYHOVUJE požadavkům. Kritické rozměrové odchylky a chybějící prvky. Nutná reklamace.',
    );
  }

  DefectLocation _generateRandomLocation() {
    return DefectLocation(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      width: 0.05 + _random.nextDouble() * 0.15,
      height: 0.05 + _random.nextDouble() * 0.15,
    );
  }
}