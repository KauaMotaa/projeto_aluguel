import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Etiqueta de estado. O estado vira construtor, nao condicional
/// espalhado pela tela.
class StatusBadge extends StatelessWidget {
  const StatusBadge._({
    required this.label,
    required this.cor,
    required this.fundo,
  });

  factory StatusBadge.aberta({String label = 'Aberta'}) => StatusBadge._(
        label: label,
        cor: AppColors.warning,
        fundo: AppColors.warningSurface,
      );

  factory StatusBadge.paga({String label = 'Paga'}) => StatusBadge._(
        label: label,
        cor: AppColors.success,
        fundo: AppColors.successSurface,
      );

  factory StatusBadge.atrasada({String label = 'Atrasada'}) => StatusBadge._(
        label: label,
        cor: AppColors.danger,
        fundo: AppColors.dangerSurface,
      );

  factory StatusBadge.vaga({String label = 'Vaga'}) => StatusBadge._(
        label: label,
        cor: AppColors.neutral,
        fundo: AppColors.neutralSurface,
      );

  /// Monta a partir do status que a API devolve.
  factory StatusBadge.doStatus(String? status) {
    switch (status) {
      case 'paga':
        return StatusBadge.paga();
      case 'atrasada':
        return StatusBadge.atrasada();
      case 'aberta':
        return StatusBadge.aberta();
      default:
        return StatusBadge.vaga(label: 'Sem cobranca');
    }
  }

  final String label;
  final Color cor;
  final Color fundo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor),
      ),
    );
  }
}
