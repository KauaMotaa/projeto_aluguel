import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Linha rotulo + valor, usada na quebra da cobranca.
class ValueRow extends StatelessWidget {
  const ValueRow._({
    required this.label,
    required this.valor,
    required this.estiloLabel,
    required this.estiloValor,
    this.separador = false,
  });

  factory ValueRow.normal({required String label, required String valor}) =>
      ValueRow._(
        label: label,
        valor: valor,
        estiloLabel: AppTypography.body.copyWith(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        estiloValor: AppTypography.body.copyWith(fontSize: 13),
      );

  factory ValueRow.total({required String label, required String valor}) =>
      ValueRow._(
        label: label,
        valor: valor,
        estiloLabel: AppTypography.subtitle.copyWith(fontSize: 15),
        estiloValor: AppTypography.subtitle.copyWith(fontSize: 15),
        separador: true,
      );

  final String label;
  final String valor;
  final TextStyle estiloLabel;
  final TextStyle estiloValor;
  final bool separador;

  @override
  Widget build(BuildContext context) {
    final linha = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: Text(label, style: estiloLabel)),
        const SizedBox(width: 12),
        Text(valor, style: estiloValor),
      ],
    );

    if (!separador) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: linha,
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEF0EE))),
      ),
      child: linha,
    );
  }
}
