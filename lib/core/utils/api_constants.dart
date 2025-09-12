class ApiConstants {
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  
  // Dostupné modely
  static const String gemini25Flash = 'gemini-2.5-flash';         // Výchozí rychlý model
  static const String gemini15Pro = 'gemini-1.5-pro';            // Nejlepší přesný model
  static const String gemini20FlashExp = 'gemini-2.0-flash-exp'; // Experimentální model
  
  static const String defaultModel = gemini25Flash; // Výchozí rychlý model
  
  // Dynamický endpoint na základě zvoleného modelu
  static String generateContentEndpoint(String model) => '/models/$model:generateContent';
  
  static const int maxImageSizeMB = 20;
  static const int maxImageSizeBytes = maxImageSizeMB * 1024 * 1024;
  
  static const Duration requestTimeout = Duration(seconds: 180); // 3 minuty na analýzu
  
  // Popis modelů pro UI
  static const Map<String, String> modelDescriptions = {
    gemini25Flash: 'Gemini 2.5 Flash - Rychlý výchozí model',
    gemini15Pro: 'Gemini 1.5 Pro - Nejlepší přesný model',
    gemini20FlashExp: 'Gemini 2.0 Flash Exp - Experimentální',
  };
}