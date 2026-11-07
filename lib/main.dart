import 'package:flutter/material.dart';
import 'branding/omnix_brand.dart';
import 'screens/utilities_hub_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OmnixApp());
}

class OmnixApp extends StatelessWidget {
  const OmnixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: OmnixBrand.name,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const UtilitiesHubScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? OmnixBrand.navy : OmnixBrand.mist;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: OmnixBrand.primary,
      primary: OmnixBrand.primary,
      surface: base,
      brightness: brightness,
    );
    final textTheme = ThemeData(colorScheme: colorScheme).textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardColor: isDark
          ? const Color(0xFF2A2A2E).withValues(alpha: 0.5)
          : Colors.white.withValues(alpha: 0.55),
    );
  }
}
