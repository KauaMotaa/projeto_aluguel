import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  static OutlineInputBorder _borda(Color cor, [double largura = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall + 2),
        borderSide: BorderSide(color: cor, width: largura),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        textTheme: const TextTheme(
          headlineLarge: AppTypography.display,
          titleLarge: AppTypography.title,
          titleMedium: AppTypography.subtitle,
          bodyMedium: AppTypography.body,
          bodySmall: AppTypography.caption,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + AppSpacing.xs,
            vertical: AppSpacing.sm + AppSpacing.xs,
          ),
          border: _borda(AppColors.borderStrong),
          enabledBorder: _borda(AppColors.borderStrong),
          focusedBorder: _borda(AppColors.primary, 1.5),
          errorBorder: _borda(AppColors.danger, 1.5),
          focusedErrorBorder: _borda(AppColors.danger, 1.5),
          errorStyle: const TextStyle(fontSize: 11, color: AppColors.danger),
        ),
      );
}
