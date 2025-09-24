import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/gemini_service.dart';
import '../../core/utils/api_constants.dart';

class SettingsState {
  final String selectedModel;
  final String apiKey;
  final bool isLoading;
  final String? error;
  final bool isApiKeyValid;

  const SettingsState({
    this.selectedModel = ApiConstants.defaultModel,
    this.apiKey = '',
    this.isLoading = false,
    this.error,
    this.isApiKeyValid = false,
  });

  SettingsState copyWith({
    String? selectedModel,
    String? apiKey,
    bool? isLoading,
    String? error,
    bool? isApiKeyValid,
  }) {
    return SettingsState(
      selectedModel: selectedModel ?? this.selectedModel,
      apiKey: apiKey ?? this.apiKey,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isApiKeyValid: isApiKeyValid ?? this.isApiKeyValid,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  final GeminiService _geminiService;

  SettingsController(this._geminiService) : super(const SettingsState());

  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedModel = prefs.getString('selected_gemini_model') ?? ApiConstants.defaultModel;
      final apiKey = await ApiConstants.getGeminiApiKey() ?? '';
      
      state = state.copyWith(
        selectedModel: selectedModel,
        apiKey: apiKey,
        isLoading: false,
        error: null,
        isApiKeyValid: apiKey.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Chyba při načítání nastavení: $e',
      );
    }
  }

  Future<void> saveSettings() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_gemini_model', state.selectedModel);
      
      if (state.apiKey.isNotEmpty) {
        await ApiConstants.setGeminiApiKey(state.apiKey);
      }

      state = state.copyWith(
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Chyba při ukládání nastavení: $e',
      );
    }
  }

  Future<void> resetToDefaults() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_gemini_model');
      await prefs.remove('gemini_api_key'); // Legacy key cleanup
      
      state = state.copyWith(
        selectedModel: ApiConstants.defaultModel,
        apiKey: '',
        isLoading: false,
        error: null,
        isApiKeyValid: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Chyba při resetování nastavení: $e',
      );
    }
  }

  Future<void> verifyModel() async {
    if (state.apiKey.isEmpty) {
      state = state.copyWith(error: 'Nejdříve zadejte API klíč');
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final isValid = await _geminiService.verifyApiModel(state.selectedModel);
      state = state.copyWith(
        isLoading: false,
        error: isValid ? null : 'Model není dostupný nebo API klíč je neplatný',
        isApiKeyValid: isValid,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Chyba při ověřování modelu: $e',
        isApiKeyValid: false,
      );
    }
  }

  Future<void> testApiKey() async {
    if (state.apiKey.isEmpty) {
      state = state.copyWith(error: 'Zadejte API klíč');
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      await ApiConstants.setGeminiApiKey(state.apiKey);
      final isValid = await _geminiService.verifyApiModel(state.selectedModel);
      
      state = state.copyWith(
        isLoading: false,
        error: isValid ? null : 'API klíč je neplatný nebo model není dostupný',
        isApiKeyValid: isValid,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Chyba při testování API klíče: $e',
        isApiKeyValid: false,
      );
    }
  }

  Future<String> exportSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = {
        'selected_gemini_model': state.selectedModel,
        'api_key_set': state.apiKey.isNotEmpty,
        'exported_at': DateTime.now().toIso8601String(),
      };
      return settings.toString();
    } catch (e) {
      throw Exception('Chyba při exportu nastavení: $e');
    }
  }

  void updateSelectedModel(String model) {
    state = state.copyWith(selectedModel: model, error: null);
  }

  void updateApiKey(String apiKey) {
    state = state.copyWith(
      apiKey: apiKey, 
      error: null,
      isApiKeyValid: false, // Reset validation when key changes
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final settingsControllerProvider = StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController(ref.watch(geminiServiceProvider));
});