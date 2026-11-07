import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Escala tipografica do design system.
///
/// FontFeature.tabularFigures mantem todos os algarismos com a mesma
/// largura. Sem isso a coluna de valores fica torta quando os numeros
/// mudam, que e o defeito mais visivel num app de dinheiro.
class AppTypography {
  const AppTypography._();

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: AppColors.textPrimary,
    fontFeatures: tabular,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFeatures: tabular,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
    fontFeatures: tabular,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    fontFeatures: tabular,
  );
}
