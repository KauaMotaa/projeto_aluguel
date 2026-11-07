import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';

/// Campo de leitura de medidor.
///
/// Mostra a leitura anterior logo abaixo e recusa valor menor que ela.
/// Erro de digitacao em leitura de medidor e a falha mais comum desse tipo
/// de sistema, e e barata de prevenir aqui, antes de chegar na API.
class MeterInput extends StatelessWidget {
  const MeterInput({
    super.key,
    required this.rotulo,
    required this.tipo,
    required this.valorAnterior,
    required this.controller,
    required this.onChanged,
    this.erro,
    this.aviso,
  });

  final String rotulo;
  final String tipo;
  final double valorAnterior;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? erro;

  /// Consumo fora do padrao da unidade. Nao e erro: o campo continua
  /// valido e o botao de salvar segue ligado. Por isso ambar, e nao
  /// vermelho, e por isso fica abaixo da legenda em vez de no lugar dela.
  final String? aviso;

  String _legenda() {
    final casas = tipo == 'agua' ? 1 : 0;
    final anterior = Formatters.numero(valorAnterior, casas: casas);
    final base = 'Anterior: $anterior';

    if (erro != null) return base;

    final atual = double.tryParse(controller.text.replaceAll(',', '.'));
    if (atual == null) return base;

    final consumo = atual - valorAnterior;
    if (consumo < 0) return base;

    return '$base  ·  consumo ${Formatters.consumo(consumo, tipo)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: AppTypography.caption),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: AppTypography.subtitle,
          decoration: InputDecoration(errorText: erro),
        ),
        const SizedBox(height: 5),
        Text(
          _legenda(),
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            color: erro != null ? AppColors.danger : AppColors.textSecondary,
          ),
        ),
        if (aviso != null && erro == null) ...[
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.error_outline,
                    size: 13, color: AppColors.warning),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  aviso!,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
