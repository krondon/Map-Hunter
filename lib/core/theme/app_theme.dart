import 'package:flutter/material.dart';

class AppTheme {
  // --- DARK PALETTE (The Void) ---
  static const Color dGoldMain = Color(0xFFFECB00);
  static const Color dGoldLight = Color(0xFFFFF176);
  static const Color dGoldDark = Color(0xFFFBC02D);
  static const Color dGoldMuted = Color(0xFFB8860B);
  
  static const Color dBrandMain = Color(0xFF7B2CBF);
  static const Color dBrandLight = Color(0xFFA29BFE);
  static const Color dBrandDark = Color(0xFF4834D4);
  static const Color dBrandDeep = Color(0xFF150826);
  
  static const Color dSurface0 = Color(0xFF0D0D0F); // Background absolute
  static const Color dSurface1 = Color(0xFF1A1A1D); // Cards
  static const Color dSurface2 = Color(0xFF2D3436); // Modals/Overlays
  static const Color dSurface3 = Color(0xFF3D4461); // Elevated
  static const Color dBorder = Color(0xFF3D3D4D);
  
  // --- LIGHT PALETTE (Crystal Clarity) ---
  static const Color lGoldAction = Color(0xFFFFD700);
  static const Color lGoldText = Color(0xFFB8860B);
  static const Color lGoldSurface = Color(0xFFFFFDE7);
  
  static const Color lBrandMain = Color(0xFF5A189A);
  static const Color lBrandSurface = Color(0xFFE9D5FF);
  static const Color lBrandDeep = Color(0xFF3C096C);
  
  static const Color lSurface0 = Color(0xFFF2F2F7); // Background absolute
  static const Color lSurface1 = Color(0xFFFFFFFF); // Cards
  static const Color lSurfaceAlt = Color(0xFFD1D1DB); // Secondary fields
  static const Color lBorder = Color(0xFFD1D1DB);
  
  // legacy aliases for backward compatibility
  static const Color accentGold = dGoldMain;
  static const Color darkBg = dSurface0;
  static const Color cardBg = dSurface1;
  static const Color dangerRed = Color(0xFFFF4757);
  static const Color successGreen = Color(0xFF00D9A3);
  static const Color primaryPurple = Color(0xFF7B2CBF);
  static const Color secondaryPink = Color(0xFFD42AB3);
  static const Color warningOrange = Color(0xFFFF9F43);
  static const Color neonGreen = Color(0xFF00D9A3);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, secondaryPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [dSurface0, Color(0xFF1A1A1D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [dGoldMain, dGoldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    
    final Color bg = isDark ? dSurface0 : lSurface0;
    final Color surface = isDark ? dSurface1 : lSurface1;
    final Color primary = isDark ? dBrandMain : lBrandMain;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1A1A1D);
    final Color textSec = isDark ? Colors.white70 : const Color(0xFF4A4A5A);

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        secondary: isDark ? dGoldMain : lGoldAction,
        surface: surface,
        background: bg,
        error: dangerRed,
        onPrimary: Colors.white,
        onSecondary: isDark ? Colors.black : Colors.white,
        onSurface: textColor,
        onBackground: textColor,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
        bodyLarge: TextStyle(fontSize: 16, color: textSec),
        bodyMedium: TextStyle(fontSize: 14, color: textSec),
        labelLarge: const TextStyle(fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 0 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? dBorder : lBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 2)),
      ),
    );
  }
}
