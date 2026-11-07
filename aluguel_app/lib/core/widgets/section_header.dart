import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Cabecalho de um ponto (imovel) na lista de unidades, com o subtotal.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.endereco,
    this.valor,
  });

  final String endereco;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.place_outlined,
              size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              endereco,
              style: AppTypography.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (valor != null)
            Text(
              valor!,
              style: AppTypography.caption.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
