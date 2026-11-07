import 'package:flutter/material.dart';

/// Tokens de cor do design system.
///
/// As tres cores semanticas (sucesso, alerta, perigo) aparecem apenas em
/// StatusBadge e em mensagem de erro. Se escaparem para outros lugares,
/// perdem a funcao de sinalizar estado.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF15514C);
  static const Color primaryMuted = Color(0xFF1E7A72);
  static const Color primarySurface = Color(0xFFDCEEEB);
  static const Color onPrimaryMuted = Color(0xFFA9CFC9);

  static const Color background = Color(0xFFF7F8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF2F5F3);
  static const Color border = Color(0xFFE3E6E3);
  static const Color borderStrong = Color(0xFFC9D0CD);

  static const Color textPrimary = Color(0xFF16201E);
  static const Color textSecondary = Color(0xFF5E6B68);

  static const Color success = Color(0xFF1F5C39);
  static const Color successSurface = Color(0xFFE3F1E8);
  static const Color warning = Color(0xFF7A5400);
  static const Color warningSurface = Color(0xFFFBF0D9);
  static const Color danger = Color(0xFF8C1D18);
  static const Color dangerSurface = Color(0xFFFBE9E7);
  static const Color neutral = Color(0xFF4A5553);
  static const Color neutralSurface = Color(0xFFECEEEB);
}
