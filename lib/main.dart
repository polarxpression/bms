import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bms/firebase_options.dart';
import 'package:bms/state/app_state.dart';
import 'package:bms/ui/main_layout.dart';
import 'package:bms/core/services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // Catch errors at the very root level
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const AppRoot());
  }, (error, stack) {
    debugPrint('ROOT ERROR: $error');
    debugPrint(stack.toString());
  });
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // 1. Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Initialize Date Formatting
      await initializeDateFormatting('pt_BR', null);

      // 3. Initialize Notifications (non-blocking, but we start it here)
      // We don't await this to block UI, but we log errors if they happen
      NotificationService().init().catchError((e) {
        debugPrint('Notification Service Error: $e');
      });

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e, s) {
      debugPrint('Initialization Error: $e');
      debugPrintStack(stackTrace: s);
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we have an error, show it nicely
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Erro ao iniciar o app',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // While initializing, show a splash/loading screen
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFFEC4899)),
          ),
        ),
      );
    }

    // Once initialized, show the main app
    return const BMSApp();
  }
}

class BMSApp extends StatelessWidget {
  const BMSApp({super.key});
// ... rest of the class remains same

  @override
  Widget build(BuildContext context) {
    const Color accentPink = Color(0xFFEC4899);
    const Color bgColor = Color(0xFF050505);
    const Color surfaceColor = Color(0xFF141414);

    return AppStateProvider(
      notifier: AppState(),
      child: MaterialApp(
        title: 'PowerTrack BMS',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          useMaterial3: true,
          visualDensity:
              VisualDensity.compact, // Tighter layout for desktop/pro feel
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bgColor,
          colorScheme: ColorScheme.fromSeed(
            seedColor: accentPink,
            primary: accentPink,
            brightness: Brightness.dark,
            surface: surfaceColor,
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            bodyLarge: TextStyle(fontSize: 14),
            bodyMedium: TextStyle(fontSize: 13),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: bgColor,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: const Color(0xFF27272A),
            indicatorColor: accentPink.withValues(alpha: 0.2),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: accentPink);
              }
              return const IconThemeData(color: Colors.grey);
            }),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: accentPink,
            foregroundColor: Colors.white,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(backgroundColor: accentPink),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: accentPink),
            ),
            labelStyle: const TextStyle(color: Colors.white70),
          ),
        ),
        home: const MainLayoutShell(),
      ),
    );
  }
}
