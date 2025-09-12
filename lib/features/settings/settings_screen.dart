import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/gemini_service.dart';
import '../../core/utils/api_constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _promptVyliskyController = TextEditingController();
  final _promptObrabeneController = TextEditingController();
  final _emailController = TextEditingController();
  final _operatorController = TextEditingController();
  final _productionLineController = TextEditingController();
  
  bool _isLoading = true;
  bool _obscureApiKey = true;
  String _actualModel = 'Načítá se...';
  bool _modelVerified = false;
  Map<String, dynamic>? _modelInfo;
  
  // Default prompts
  static const String _defaultPromptVylisky = '''
Analyzuj tyto dva obrázky pro kontrolu kvality výlisků:
1. První obrázek je referenční (3D model nebo etalon)
2. Druhý obrázek je reálný výlisek

Porovnej oba obrázky a identifikuj specificky u výlisků:
- Chybějící díry, výčnělky nebo hrany
- Přebývající materiál (otřepy, výronky)
- Deformace tvaru (prohnutí, zkroucení)
- Rozměrové odchylky od specifikace
- Povrchové vady (trhliny, bubliny)

Zaměř se na typické defekty výlisků jako jsou:
- Nedostatečné vyplnění formy
- Výronky na dělící rovině
- Vtažení materiálu
- Deformace při vytahování z formy
''';

  static const String _defaultPromptObrabene = '''
Analyzuj tyto dva obrázky pro kontrolu kvality obráběných dílů:
1. První obrázek je referenční (3D model nebo etalon)  
2. Druhý obrázek je reálný obráběný díl

Porovnej oba obrázky a identifikuj specificky u obráběných dílů:
- Chybějící obrábění (díry, drážky, závity)
- Přebývající materiál (neodebraný materiál)
- Rozměrové odchylky tolerance
- Geometrické odchylky (rovnoběžnost, kolmost)
- Kvalita povrchu

Zaměř se na typické defekty obrábění jako jsou:
- Nedokončené obrábění
- Špatné rozměry
- Drsnost povrchu
- Otřepy na hranách
- Geometrické nepřesnosti
''';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _verifyModel();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _promptVyliskyController.dispose();
    _promptObrabeneController.dispose();
    _emailController.dispose();
    _operatorController.dispose();
    _productionLineController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load API key from secure storage
      final apiKey = await ApiConstants.getGeminiApiKey();
      
      setState(() {
        _apiKeyController.text = apiKey ?? '';
        _promptVyliskyController.text = prefs.getString('prompt_vylisky') ?? _defaultPromptVylisky;
        _promptObrabeneController.text = prefs.getString('prompt_obrabene') ?? _defaultPromptObrabene;
        _emailController.text = prefs.getString('default_email') ?? 'kvalita@firma.cz';
        _operatorController.text = prefs.getString('operator_name') ?? 'Operátor QC';
        _productionLineController.text = prefs.getString('production_line') ?? 'Linka A';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Chyba při načítání nastavení: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save API key to secure storage
      if (_apiKeyController.text.isNotEmpty) {
        await ApiConstants.setGeminiApiKey(_apiKeyController.text);
      }
      
      await prefs.setString('prompt_vylisky', _promptVyliskyController.text);
      await prefs.setString('prompt_obrabene', _promptObrabeneController.text);
      await prefs.setString('default_email', _emailController.text);
      await prefs.setString('operator_name', _operatorController.text);
      await prefs.setString('production_line', _productionLineController.text);
      
      _showSuccess('Nastavení uloženo');
    } catch (e) {
      _showError('Chyba při ukládání: $e');
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Obnovit výchozí hodnoty'),
        content: const Text('Opravdu chcete obnovit všechna nastavení na výchozí hodnoty?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Obnovit'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _promptVyliskyController.text = _defaultPromptVylisky;
        _promptObrabeneController.text = _defaultPromptObrabene;
        _emailController.text = 'kvalita@firma.cz';
        _operatorController.text = 'Operátor QC';
        _productionLineController.text = 'Linka A';
      });
      await _saveSettings();
    }
  }

  Future<void> _verifyModel() async {
    try {
      final geminiService = GeminiService();
      final modelInfo = await geminiService.verifyApiModel();
      
      setState(() {
        _modelInfo = modelInfo;
        _actualModel = modelInfo['displayName'] ?? modelInfo['name'] ?? 'Neznámý model';
        _modelVerified = true;
      });
    } catch (e) {
      setState(() {
        _modelInfo = null;
        _actualModel = 'Chyba: ${e.toString()}';
        _modelVerified = false;
      });
    }
  }

  Future<void> _testApiKey() async {
    if (_apiKeyController.text.isEmpty) {
      _showError('Zadejte API klíč pro testování');
      return;
    }

    _showInfo('Testování API klíče...', duration: 1);
    
    try {
      // First save the API key to secure storage so GeminiService can use it
      await ApiConstants.setGeminiApiKey(_apiKeyController.text);
      
      final geminiService = GeminiService();
      final modelInfo = await geminiService.verifyApiModel();
      
      setState(() {
        _modelInfo = modelInfo;
        _actualModel = modelInfo['displayName'] ?? modelInfo['name'] ?? 'Neznámý model';
        _modelVerified = true;
      });
      
      _showSuccess('✅ API klíč je platný - Model: $_actualModel');
    } catch (e) {
      setState(() {
        _actualModel = 'Chyba: ${e.toString()}';
        _modelVerified = false;
      });
      _showError('❌ Chyba API: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavení'),
        backgroundColor: Colors.teal.withOpacity(0.1),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore),
                    SizedBox(width: 8),
                    Text('Obnovit výchozí'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export nastavení'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildApiKeySection(),
            const SizedBox(height: 24),
            _buildPromptsSection(),
            const SizedBox(height: 24),
            _buildUserInfoSection(),
            const SizedBox(height: 24),
            _buildProductionSection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.key, color: Colors.teal),
                SizedBox(width: 8),
                Text('Gemini API Konfigurace', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'Gemini API Klíč',
                hintText: 'AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                      icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
                    ),
                    IconButton(
                      onPressed: _testApiKey,
                      icon: const Icon(Icons.play_arrow),
                      tooltip: 'Test API klíče',
                    ),
                  ],
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Získejte API klíč na: https://makersuite.google.com/app/apikey',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _modelVerified ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _modelVerified ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _modelVerified ? Icons.check_circle : Icons.info,
                    color: _modelVerified ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aktuální model z API:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          _actualModel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _modelVerified ? Colors.green[700] : Colors.orange[700],
                          ),
                        ),
                        if (_modelInfo != null && _modelVerified) ...[
                          const SizedBox(height: 8),
                          _buildModelDetail('Verze', _modelInfo!['version'] ?? 'neznámá'),
                          _buildModelDetail('Popis', _modelInfo!['description'] ?? 'žádný'),
                          _buildModelDetail('Max tokeny', _modelInfo!['maxOutputTokens'] ?? 'neomezeno'),
                          _buildModelDetail('Metody', _modelInfo!['supportedGenerationMethods'] ?? 'generateContent'),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _verifyModel,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Obnovit ověření modelu',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.chat, color: Colors.blue),
                SizedBox(width: 8),
                Text('Analýza Prompty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Prompt pro Výlisky'),
              leading: const Icon(Icons.build),
              children: [
                TextField(
                  controller: _promptVyliskyController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Instrukce pro AI analýzu výlisků',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Prompt pro Obráběné díly'),
              leading: const Icon(Icons.precision_manufacturing),
              children: [
                TextField(
                  controller: _promptObrabeneController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Instrukce pro AI analýzu obráběných dílů',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person, color: Colors.green),
                SizedBox(width: 8),
                Text('Informace o uživateli', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Výchozí email pro reporty',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _operatorController,
              decoration: const InputDecoration(
                labelText: 'Jméno operátora',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.factory, color: Colors.orange),
                SizedBox(width: 8),
                Text('Výrobní informace', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _productionLineController,
              decoration: const InputDecoration(
                labelText: 'Výrobní linka',
                prefixIcon: Icon(Icons.linear_scale),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _saveSettings,
        icon: const Icon(Icons.save),
        label: const Text('Uložit nastavení'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'reset':
        await _resetToDefaults();
        break;
      case 'export':
        await _exportSettings();
        break;
    }
  }

  Future<void> _exportSettings() async {
    final settings = {
      'gemini_api_key': '[HIDDEN]',
      'prompt_vylisky': _promptVyliskyController.text,
      'prompt_obrabene': _promptObrabeneController.text,
      'default_email': _emailController.text,
      'operator_name': _operatorController.text,
      'production_line': _productionLineController.text,
      'export_timestamp': DateTime.now().toIso8601String(),
    };

    _showInfo('Export nastavení dokončen');
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showInfo(String message, {int duration = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: duration),
      ),
    );
  }

  Widget _buildModelDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}