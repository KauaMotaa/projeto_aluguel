import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Um mes no grafico de consumo.
class BarraConsumo {
  const BarraConsumo({
    required this.rotulo,
    required this.valor,
    required this.texto,
  });

  /// O mes, curto: "Nov".
  final String rotulo;

  /// O consumo cru, que define a altura. Nulo quando nao houve leitura —
  /// e nao e zero: nao lancado e diferente de nao consumiu.
  final double? valor;

  /// O mesmo consumo ja formatado, com a unidade.
  final String texto;
}

/// Consumo mes a mes, em barras.
///
/// Uma tabela de numeros responde "quanto gastei em outubro". A barra
/// responde "estou gastando mais que antes", que e a pergunta que a
/// pessoa tem olhando a conta — e que numero nenhum responde sozinho.
///
/// Mes sem leitura vira um tracinho no chao, nao uma barra de altura
/// zero: zero e uma informacao, e esta nao e.
class BarrasConsumo extends StatelessWidget {
  const BarrasConsumo({
    super.key,
    required this.barras,
    required this.cor,
    this.altura = 64,
  });

  final List<BarraConsumo> barras;
  final Color cor;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final valores = [
      for (final barra in barras)
        if (barra.valor != null) barra.valor!
    ];
    // Sem nada lancado nao ha escala, e dividir por zero daria barra
    // infinita. A escala tambem nunca e menor que o maior valor.
    final maximo = valores.isEmpty
        ? 0.0
        : valores.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final barra in barras)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    barra.texto,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: barra.valor == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: altura,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: _alturaDa(barra, maximo),
                        decoration: BoxDecoration(
                          color: barra.valor == null
                              ? AppColors.border
                              : cor,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall / 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    barra.rotulo,
                    maxLines: 1,
                    style: AppTypography.caption.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Altura proporcional ao maior mes. O piso de 3px existe para um mes
  /// de consumo muito baixo nao sumir da tela.
  double _alturaDa(BarraConsumo barra, double maximo) {
    if (barra.valor == null) return 3;
    if (maximo <= 0) return 3;
    return 3 + (barra.valor! / maximo) * (altura - 3);
  }
}
