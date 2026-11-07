import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Superficie padrao do app: fundo branco, borda fina, raio 12.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.destaque = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool destaque;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final conteudo = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: destaque ? AppColors.primarySurface : AppColors.surface,
        border: Border.all(
          color: destaque ? const Color(0xFFB9DDD7) : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: child,
    );

    if (onTap == null) return conteudo;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      child: conteudo,
    );
  }
}
