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

  /// A marca, na tela de entrada. Mesmo tamanho do [display], mas sobre o
  /// fundo primario e sem algarismo tabular, que ali nao serve.
  static const TextStyle marca = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.onPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Titulo de tela, no AppBar. Menor que [title] porque divide a barra
  /// com a linha de contexto logo abaixo. Sem cor: quem a define e o
  /// `AppBarTheme`, e fixar aqui brigaria com ele.
  static const TextStyle appBar = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  /// Rotulo de botao.
  static const TextStyle botao = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Botao de texto dentro de um card ou alerta, onde o espaco e curto.
  static const TextStyle botaoCompacto = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Etiqueta de estado. Sem cor: cada estado traz a sua.
  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
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
