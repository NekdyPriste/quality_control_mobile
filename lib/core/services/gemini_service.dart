import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comparison_result.dart';
import '../models/quality_report.dart';
import '../models/defect.dart';
import '../utils/api_constants.dart';
import '../utils/secure_http_client.dart';

// Custom exception class pro lepší error handling
class GeminiServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  const GeminiServiceException(this.message, {this.code, this.originalException});

  @override
  String toString() => 'GeminiServiceException: $message${code != null ? ' (Code: $code)' : ''}';
}

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

class GeminiService {
  final SecureHttpClient _secureHttpClient = SecureHttpClient();
  
  Future<String> getCurrentModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_gemini_model') ?? ApiConstants.defaultModel;
  }
  
  Future<void> setCurrentModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_gemini_model', model);
  }
  
  Future<Map<String, dynamic>> verifyApiModel([String? model]) async {
    try {
      // Použití secure storage místo SharedPreferences
      final apiKey = await ApiConstants.getGeminiApiKey();
      final selectedModel = model ?? await getCurrentModel();
      
      if (apiKey == null || apiKey.isEmpty) {
        // Fallback na environment variable pro demo
        final fallbackKey = ApiConstants.fallbackApiKey;
        if (fallbackKey == 'YOUR_GEMINI_API_KEY_HERE') {
          throw Exception('API klíč není nastaven. Prosím nastavte klíč v nastavení aplikace.');
        }
      }
      
      // Použití správného API klíče (secure storage nebo fallback)
      final finalApiKey = apiKey ?? ApiConstants.fallbackApiKey;
      
      final secureClient = SecureHttpClient();
      final response = await secureClient.get(
        Uri.parse('${ApiConstants.geminiBaseUrl}/models/$selectedModel'),
        headers: {
          'x-goog-api-key': finalApiKey,
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'name': data['name'] ?? selectedModel,
          'displayName': data['displayName'] ?? 'Neznámý model',
          'description': data['description'] ?? 'Žádný popis',
          'version': data['version'] ?? 'neznámá',
          'baseModelId': data['baseModelId'] ?? selectedModel,
          'temperature': data['temperature']?.toString() ?? 'výchozí',
          'topP': data['topP']?.toString() ?? 'výchozí',
          'topK': data['topK']?.toString() ?? 'výchozí',
          'maxOutputTokens': data['maxOutputTokens']?.toString() ?? 'neomezeno',
          'inputTokenLimit': data['inputTokenLimit']?.toString() ?? 'neomezeno',
          'supportedGenerationMethods': (data['supportedGenerationMethods'] as List?)?.join(', ') ?? 'generateContent',
        };
      } else {
        throw Exception('API model verification failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Chyba při ověřování modelu: $e');
    }
  }
  
  Future<String> getModelDisplayName() async {
    try {
      final model = await getCurrentModel();
      final modelInfo = await verifyApiModel(model);
      return modelInfo['displayName'] ?? modelInfo['name'] ?? model;
    } catch (e) {
      final model = await getCurrentModel();
      return ApiConstants.modelDescriptions[model] ?? model;
    }
  }
  
  Future<List<String>> getAvailableModels() async {
    return [
      ApiConstants.gemini25Flash,    // Výchozí rychlý
      ApiConstants.gemini15Pro,     // Nejlepší přesný  
      ApiConstants.gemini20FlashExp, // Experimentální
    ];
  }
  
  static const String _qualityControlPrompt = '''
KONTROLA KOMPLETNOSTI DÍLU:

Porovnej referenční obrázek (první) s kontrolovaným dílem (druhý).

⚠️ DŮLEŽITÉ - IGNORUJ BARVY:
- NEPOROVNÁVEJ barvy, odstíny nebo povrchové úpravy
- Zákazníci často mají chybně obarvené díly nebo různé povrchové úpravy
- Zaměř se POUZE na geometrii, tvar a kompletnost dílu
- Barva NENÍ defekt - ignoruj ji úplně

Zaměř se POUZE na tyto 2 hlavní problémy:

1. CHYBĚJÍCÍ ČÁSTI:
   - Má díl všechny požadované prvky jako reference?
   - Chybí nějaké otvory, výstupky, nebo části?
   - Je díl kompletní?
   - Má správnou geometrii a tvar?

2. PŘEBÝVAJÍCÍ MATERIÁL:
   - Je na dílu něco navíc oproti referenci?
   - Jsou tam otřepy, nálitky nebo nečistoty?
   - Přebývá materiál někde kde nemá být?
   - Má díl nesprávné rozměry nebo tvar?

VÝSTUPNÍ FORMÁT (pouze validní JSON):
{
  "overall_quality": "PASS|FAIL|WARNING",
  "confidence_score": 0.95,
  "summary": "VÝSLEDEK KONTROLY:\n\nKONTROLOVANÉ OBLASTI:\n- Kompletnost všech prvků dílu\n- Přítomnost přebývajícího materiálu\n- Shoda s referenčním vzorkem\n\nZJIŠTĚNÍ:\n- Popis hlavních zjištění zde\n- Další důležité pozorování\n\nZÁVĚR:\nDíl vyhovuje/nevyhovuje požadavkům",
  "defects": [
    {
      "type": "MISSING|EXTRA",
      "severity": "MINOR|MAJOR|CRITICAL", 
      "description": "Popis česky - co přesně chybí nebo přebývá",
      "location": {"x": 0.5, "y": 0.3, "width": 0.1, "height": 0.2},
      "confidence": 0.85
    }
  ]
}

PRAVIDLA:
- Používej POUZE typy "MISSING" (chybí) nebo "EXTRA" (přebývá)
- Souřadnice jako relativní pozice (0.0-1.0)
- Český popis defektů
- CRITICAL = díl nelze použít, MAJOR = problém s funkcí, MINOR = kosmetická vada
- Summary musí obsahovat strukturu: VÝSLEDEK KONTROLY -> KONTROLOVANÉ OBLASTI -> ZJIŠTĚNÍ -> ZÁVĚR
- Používej nadpisy velkými písmeny s dvojtečkou (např. "ZJIŠTĚNÍ:")
- Každé zjištění na nový řádek se seznamem (začínat s "- ")
- Závěr musí obsahovat jasné "vyhovuje" nebo "nevyhovuje"
- ⚠️ NIKDY neoznač barvu jako defekt - ignoruj rozdíly v barvách
- Zaměř se POUZE na 3D geometrii, tvar a kompletnost dílu
- Vrať POUZE JSON
''';

  Future<ComparisonResult> analyzeImages({
    required File referenceImage,
    required File partImage,
    required PartType partType,
  }) async {
    try {
      // Get API key from secure storage
      String? apiKey = await ApiConstants.getGeminiApiKey();
      
      // Fallback pro demo nebo pokud secure storage není k dispozici
      if (apiKey == null || apiKey.isEmpty) {
        apiKey = ApiConstants.fallbackApiKey;
        if (apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
          throw GeminiServiceException(
            'API klíč není nastaven. Prosím nastavte svůj Gemini API klíč v nastavení aplikace.',
            code: 'API_KEY_MISSING'
          );
        }
      }
      
      // Čtení bytů ze souborů s podporou web platformy a demo režimu
      Uint8List referenceBytes;
      Uint8List partBytes;
      
      try {
        if (kIsWeb && referenceImage.path.contains('demo_')) {
          // Pro web demo režim načítáme skutečné obrázky z assets
          referenceBytes = await _loadAssetImage('assets/demo_images/reference.jpg');
        } else {
          referenceBytes = await referenceImage.readAsBytes();
        }
      } catch (e) {
        print('Chyba při čtení referenčního obrázku: $e');
        // Pokud selže čtení souboru na webu, zkusíme načíst demo asset
        if (kIsWeb) {
          referenceBytes = await _loadAssetImage('assets/demo_images/reference.jpg');
        } else {
          rethrow;
        }
      }
      
      try {
        if (kIsWeb && partImage.path.contains('demo_')) {
          // Pro web demo režim načítáme skutečné obrázky z assets
          partBytes = await _loadAssetImage('assets/demo_images/part.jpg');
        } else {
          partBytes = await partImage.readAsBytes();
        }
      } catch (e) {
        print('Chyba při čtení obrázku dílu: $e');
        // Pokud selže čtení souboru na webu, zkusíme načíst demo asset
        if (kIsWeb) {
          partBytes = await _loadAssetImage('assets/demo_images/part.jpg');
        } else {
          rethrow;
        }
      }

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': _buildPrompt(partType)},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Encode(referenceBytes),
                }
              },
              {
                'inline_data': {
                  'mime_type': 'image/jpeg', 
                  'data': base64Encode(partBytes),
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'response_mime_type': 'application/json',
          'response_schema': _getResponseSchema(),
        }
      };

      final selectedModel = await getCurrentModel();
      final endpoint = ApiConstants.generateContentEndpoint(selectedModel);
      
      final response = await _secureHttpClient.post(
        Uri.parse('${ApiConstants.geminiBaseUrl}$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          
          // Validace response struktury
          if (!responseData.containsKey('candidates') || 
              responseData['candidates'].isEmpty) {
            throw GeminiServiceException(
              'Neočekávaný formát odpovědi z Gemini API - chybí candidates',
              code: 'INVALID_RESPONSE_FORMAT'
            );
          }
          
          final candidate = responseData['candidates'][0];
          if (!candidate.containsKey('content') || 
              !candidate['content'].containsKey('parts') ||
              candidate['content']['parts'].isEmpty) {
            throw GeminiServiceException(
              'Neočekávaný formát odpovědi z Gemini API - chybí content',
              code: 'INVALID_RESPONSE_FORMAT'
            );
          }
          
          final content = candidate['content']['parts'][0]['text'];
          
          // Parsování JSON odpovědi od Gemini
          final analysisData = jsonDecode(content);
          return _parseGeminiResponse(analysisData);
        } on FormatException catch (e) {
          throw GeminiServiceException(
            'Neplatná JSON odpověď z Gemini API',
            code: 'JSON_PARSE_ERROR',
            originalException: e
          );
        }
      } else if (response.statusCode == 401) {
        throw GeminiServiceException(
          'Neplatný API klíč. Zkontrolujte nastavení.',
          code: 'UNAUTHORIZED'
        );
      } else if (response.statusCode == 429) {
        throw GeminiServiceException(
          'Překročen limit API požadavků. Zkuste to znovu za chvíli.',
          code: 'RATE_LIMIT_EXCEEDED'
        );
      } else if (response.statusCode >= 500) {
        throw GeminiServiceException(
          'Chyba serveru Gemini API. Zkuste to znovu později.',
          code: 'SERVER_ERROR'
        );
      } else {
        throw GeminiServiceException(
          'Gemini API chyba: ${response.statusCode} - ${response.body}',
          code: 'API_ERROR'
        );
      }
    } on GeminiServiceException {
      rethrow; // Předáme naše vlastní exceptions
    } on SocketException catch (e) {
      throw GeminiServiceException(
        'Chyba síťového připojení. Zkontrolujte internetové připojení.',
        code: 'NETWORK_ERROR',
        originalException: e
      );
    } on TimeoutException catch (e) {
      throw GeminiServiceException(
        'Časový limit požadavku vypršel. Zkuste to znovu.',
        code: 'TIMEOUT_ERROR',
        originalException: e
      );
    } on FormatException catch (e) {
      throw GeminiServiceException(
        'Chyba při čtení obrázku. Zkontrolujte formát souboru.',
        code: 'IMAGE_FORMAT_ERROR',
        originalException: e
      );
    } catch (e) {
      throw GeminiServiceException(
        'Neočekávaná chyba při analýze obrázků: $e',
        code: 'UNKNOWN_ERROR',
        originalException: e
      );
    }
  }

  String _buildPrompt(PartType partType) {
    final String specificInstructions;
    
    if (partType == PartType.vylisky) {
      specificInstructions = '''
TYP DÍLU: VÝLISEK

Specifické kontroly pro výlisky:
- KOMPLETNOST STĚN: Zkontroluj, zda jsou všechny stěny a přepážky z formy kompletní
- TLOUŠŤKA STĚN: Ověř jednotnost tloušťky materiálu
- LITÉ DETAILY: Kontroluj přesnost malých prvků - závity, zápustky, žebra
- NÁLITKY A VTOKOVÝ SYSTÉM: Identifikuj zbytky vtokového systému nebo nečistoty
- SMRŠŤOVÁNÍ: Hledej deformace způsobené nerovnoměrným chladnutím
- NEDOSTATKY VYPLNĚNÍ: Kontroluj, zda je forma úplně vyplněná

ČESKÉ TERMÍNY PRO DEFEKTY VÝLISKŮ:
- "chybějící stěna", "neúplná stěna", "nedostatečné vyplnění formy"
- "přebývající materiál", "licí nálitek", "otřep na hraně"
- "deformace stěny", "prohnutí", "smrštění materiálu"
- "nesprávná tloušťka stěny", "rozměrová odchylka"
''';
    } else {
      specificInstructions = '''
TYP DÍLU: OBRÁBĚNÝ DÍL

Specifické kontroly pro obráběné díly:
- PŘESNOST ROZMĚRŮ: Kontroluj dodržení rozměrů a tolerancí
- KVALITA POVRCHU: Ověř kvalitu obrobených ploch
- ÚPLNOST OBRÁBĚNÍ: Zkontroluj, zda jsou všechny operace dokončeny
- HRANY A FAZETY: Kontroluj správnost odjehlení a fazet
- OTVORY A ZÁVITY: Ověř přesnost vrtaných otvorů a řezaných závitů

ČESKÉ TERMÍNY PRO DEFEKTY OBRÁBĚNÝCH DÍLŮ:
- "nepřesný rozměr", "překročená tolerance", "rozměrová chyba"
- "špatná kvalita povrchu", "hrubý povrch", "rýhy po obrobení"
- "chybějící fazeta", "špatné odjehlení", "ostrá hrana"
- "nepřesný otvor", "chybná poloha otvoru", "poškozený závit"
''';
    }
    
    return '''
$_qualityControlPrompt

$specificInstructions

POZOR: 
- Věnuj zvláštní pozornost mělkým detailům a malým prvkům, které mohou být špatně viditelné, ale jsou kritické pro funkčnost dílu
- ⚠️ KRITICKY DŮLEŽITÉ: NEPOROVNÁVEJ BARVY! Zákazníci mají často špatně obarvené díly
- Ignoruj úplně rozdíly v barvě, textuře povrchu nebo lesku
- Kontroluj POUZE 3D tvar, geometrii a přítomnost/nepřítomnost materiálu
''';
  }

  ComparisonResult _parseGeminiResponse(Map<String, dynamic> analysisData) {
    // Parsování skutečné JSON odpovědi od Gemini
    final overallQuality = _parseQualityStatus(analysisData['overall_quality'] ?? 'PASS');
    final confidenceScore = (analysisData['confidence_score'] ?? 0.0).toDouble();
    final summary = analysisData['summary'] ?? 'Analýza dokončena.';
    
    final defectsData = analysisData['defects_found'] ?? [];
    final defects = <Defect>[];
    
    for (final defectData in defectsData) {
      try {
        final location = defectData['location'] ?? {};
        defects.add(Defect(
          type: _parseDefectType(defectData['type'] ?? 'MISSING'),
          severity: _parseDefectSeverity(defectData['severity'] ?? 'MINOR'),
          description: defectData['description'] ?? 'Nespecifikovaný defekt',
          location: DefectLocation(
            x: (location['x'] ?? 0.5).toDouble(),
            y: (location['y'] ?? 0.5).toDouble(),
            width: (location['width'] ?? 0.1).toDouble(),
            height: (location['height'] ?? 0.1).toDouble(),
          ),
          confidence: (defectData['confidence'] ?? 0.8).toDouble(),
        ));
      } catch (e) {
        // Pokud parsing jednoho defektu selže, pokračujeme s ostatními
        print('Chyba při parsování defektu: $e');
      }
    }
    
    return ComparisonResult(
      overallQuality: overallQuality,
      confidenceScore: confidenceScore,
      defectsFound: defects,
      summary: summary,
    );
  }

  QualityStatus _parseQualityStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PASS': return QualityStatus.pass;
      case 'FAIL': return QualityStatus.fail;
      case 'WARNING': return QualityStatus.warning;
      default: return QualityStatus.pass;
    }
  }

  DefectType _parseDefectType(String type) {
    switch (type.toUpperCase()) {
      case 'MISSING': return DefectType.missing;
      case 'EXTRA': return DefectType.extra;
      case 'DEFORMED': return DefectType.deformed;
      case 'DIMENSIONAL': return DefectType.dimensional;
      default: return DefectType.missing;
    }
  }

  DefectSeverity _parseDefectSeverity(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL': return DefectSeverity.critical;
      case 'MAJOR': return DefectSeverity.major;
      case 'MINOR': return DefectSeverity.minor;
      default: return DefectSeverity.minor;
    }
  }

  Map<String, dynamic> _getResponseSchema() {
    return {
      'type': 'object',
      'properties': {
        'overall_quality': {
          'type': 'string', 
          'enum': ['PASS', 'FAIL', 'WARNING']
        },
        'confidence_score': {
          'type': 'number', 
          'minimum': 0, 
          'maximum': 1
        },
        'defects_found': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'type': {
                'type': 'string',
                'enum': ['MISSING', 'EXTRA', 'DEFORMED', 'DIMENSIONAL']
              },
              'description': {'type': 'string'},
              'severity': {
                'type': 'string',
                'enum': ['CRITICAL', 'MAJOR', 'MINOR']
              },
              'location': {
                'type': 'object',
                'properties': {
                  'x': {'type': 'number'},
                  'y': {'type': 'number'},
                  'width': {'type': 'number'},
                  'height': {'type': 'number'}
                }
              },
              'confidence': {
                'type': 'number',
                'minimum': 0,
                'maximum': 1
              }
            }
          }
        },
        'summary': {'type': 'string'}
      }
    };
  }

  Future<Uint8List> _loadAssetImage(String assetPath) async {
    try {
      final ByteData bytes = await rootBundle.load(assetPath);
      return bytes.buffer.asUint8List();
    } catch (e) {
      throw Exception('Nepodařilo se načíst obrázek z assets: $assetPath - $e');
    }
  }
}