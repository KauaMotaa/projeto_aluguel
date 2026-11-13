import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Escolha da forma de pagamento.
///
/// Fica no design system porque as duas pontas perguntam a mesma coisa: o
/// proprietario ao registrar o recebimento, o inquilino ao avisar que
/// pagou. Como todo componente daqui, nao conhece ViewModel — recebe a
/// escolha atual e devolve a nova.
class FormaPagamento extends StatelessWidget {
  const FormaPagamento({
    super.key,
    required this.formas,
    required this.selecionada,
    required this.onEscolher,
  });

  /// Chave que vai para a API, para o rotulo que aparece na tela.
  final Map<String, String> formas;
  final String selecionada;
  final ValueChanged<String> onEscolher;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final entrada in formas.entries)
          ChoiceChip(
            label: Text(entrada.value),
            selected: selecionada == entrada.key,
            onSelected: (_) => onEscolher(entrada.key),
            showCheckmark: false,
            labelStyle: AppTypography.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selecionada == entrada.key
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.primarySurface,
            side: BorderSide(
              color: selecionada == entrada.key
                  ? AppColors.primary
                  : AppColors.border,
            ),
          ),
      ],
    );
  }
}
