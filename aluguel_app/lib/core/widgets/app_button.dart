import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Botao do design system.
///
/// As variantes sao construtores nomeados (padrao Factory) em vez de um
/// parametro `tipo` com switch no build: a chamada fica legivel e a
/// variante vira parte da assinatura, nao um valor em tempo de execucao.
class AppButton extends StatelessWidget {
  const AppButton._({
    required this.label,
    required this.onPressed,
    required this.fundo,
    required this.texto,
    required this.borda,
    this.carregando = false,
  });

  factory AppButton.primary({
    required String label,
    required VoidCallback? onPressed,
    bool carregando = false,
  }) =>
      AppButton._(
        label: label,
        onPressed: onPressed,
        fundo: AppColors.primary,
        texto: Colors.white,
        borda: null,
        carregando: carregando,
      );

  factory AppButton.secondary({
    required String label,
    required VoidCallback? onPressed,
    bool carregando = false,
  }) =>
      AppButton._(
        label: label,
        onPressed: onPressed,
        fundo: AppColors.surface,
        texto: AppColors.primary,
        borda: AppColors.primary,
        carregando: carregando,
      );

  factory AppButton.danger({
    required String label,
    required VoidCallback? onPressed,
    bool carregando = false,
  }) =>
      AppButton._(
        label: label,
        onPressed: onPressed,
        fundo: AppColors.danger,
        texto: Colors.white,
        borda: null,
        carregando: carregando,
      );

  final String label;
  final VoidCallback? onPressed;
  final Color fundo;
  final Color texto;
  final Color? borda;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    final desabilitado = onPressed == null || carregando;

    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: desabilitado ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: fundo,
          foregroundColor: texto,
          disabledBackgroundColor: const Color(0xFFC3CCC9),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            side: borda == null
                ? BorderSide.none
                : BorderSide(color: borda!, width: 1.5),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: carregando
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(label),
      ),
    );
  }
}
