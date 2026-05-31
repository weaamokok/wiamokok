import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.accent,
          surface: AppColors.surface,
          onSurface: AppColors.foreground,
        ),
        textTheme: GoogleFonts.spaceGroteskTextTheme(),
      );
}
