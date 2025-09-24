import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'features/part_type_selection/part_type_screen.dart';
import 'features/demo/demo_capture_screen.dart';
import 'features/history/inspection_history_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/batch/batch_analysis_screen.dart';
import 'features/batch/background_jobs_screen.dart';
import 'core/models/quality_report.dart';
import 'core/services/background_batch_service.dart'
    if (dart.library.html) 'core/services/background_batch_service_stub.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializace SQLite pro web platformu
  if (kIsWeb) {
    // Nastavení databáze pro web
    databaseFactory = databaseFactoryFfiWeb;
  }

  // WorkManager je podporován jen na mobilních platformách
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      BackgroundBatchService.initialize();
    } catch (e) {
      print('Chyba při inicializaci WorkManager: $e');
    }
  }
  
  runApp(
    const ProviderScope(
      child: QualityControlApp(),
    ),
  );
}

class QualityControlApp extends StatelessWidget {
  const QualityControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ATQ Quality Control',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF1565C0),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1565C0), // Deep blue
              Color(0xFF1976D2), // Medium blue
              Color(0xFF2196F3), // Light blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top AppBar-like section
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ATQ Quality Control',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const InspectionHistoryScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history, color: Colors.white),
                          tooltip: 'Historie kontrol',
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (value) {
                            if (value == 'settings') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsScreen(),
                                ),
                              );
                            } else if (value == 'background_jobs') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const BackgroundJobsScreen(),
                                ),
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'background_jobs',
                              child: Row(
                                children: [
                                  Icon(Icons.work, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Background úlohy'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'settings',
                              child: Row(
                                children: [
                                  Icon(Icons.settings),
                                  SizedBox(width: 8),
                                  Text('Nastavení'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Main content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        
                        // Logo and title section
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(50),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.precision_manufacturing,
                                  size: 60,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'ATQ Quality Control',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'ATQ s.r.o. - AI kontrola kvality dílů',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w300,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Action buttons
                        _buildActionButton(
                          context: context,
                          icon: Icons.camera_alt_outlined,
                          title: 'Začít kontrolu',
                          subtitle: 'Kontrola jednotlivých dílů',
                          color: Colors.white,
                          textColor: const Color(0xFF1565C0),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PartTypeSelectionScreen(),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildActionButton(
                          context: context,
                          icon: Icons.inventory_2_outlined,
                          title: 'Batch analýza',
                          subtitle: 'Hromadná kontrola více dílů',
                          color: const Color(0xFF7B1FA2),
                          textColor: Colors.white,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BatchAnalysisScreen(),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildActionButton(
                          context: context,
                          icon: Icons.science_outlined,
                          title: 'DEMO režim',
                          subtitle: 'Zkušební analýza s ukázkovými daty',
                          color: Colors.transparent,
                          textColor: Colors.white,
                          borderColor: Colors.white.withOpacity(0.7),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DemoCaptureScreen(
                                  partType: PartType.vylisky,
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        elevation: color == Colors.transparent ? 0 : 8,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: borderColor != null 
                ? Border.all(color: borderColor, width: 2)
                : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: textColor.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}