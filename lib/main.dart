import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bms/firebase_options.dart';
import 'package:bms/state/app_state.dart';
import 'package:bms/ui/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BMSApp());
}

class BMSApp extends StatelessWidget {
  const BMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color accentPink = Color(0xFFEC4899);
    const Color bgColor = Color(0xFF050505);
    const Color surfaceColor = Color(0xFF141414);

    return AppStateProvider(
      notifier: AppState(),
      child: MaterialApp(
        title: 'BMS (Battery Management System)',
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
