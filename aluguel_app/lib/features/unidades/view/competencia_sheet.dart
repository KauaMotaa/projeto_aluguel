import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/competencia_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';

/// Lista de meses que o app conhece, para trocar a competencia.
///
/// Fica aqui, e nao em `core/widgets/`, porque le o [CompetenciaStore]: os
/// componentes do design system nao conhecem estado, recebem tudo por
/// parametro. Este conhece, entao e parte da feature.
class CompetenciaSheet {
  const CompetenciaSheet._();

  /// Abre a lista e devolve `true` quando o mes mudou de verdade — e so
  /// nesse caso que quem chamou precisa recarregar a tela.
  static Future<bool> abrir(BuildContext context) async {
    final store = context.read<CompetenciaStore>();

    final escolhido = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radius + 4),
        ),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: store,
        child: const _CompetenciaView(),
      ),
    );

    if (escolhido == null) return false;
    return store.selecionar(escolhido);
  }
}

class _CompetenciaView extends StatelessWidget {
  const _CompetenciaView();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CompetenciaStore>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),
            ),
            const Text('Competencia', style: AppTypography.title),
            const SizedBox(height: 2),
            const Text(
              'Os meses que o sistema tem lancamento, mais o mes corrente',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            if (store.opcoes.isEmpty)
              const EmptyState(
                icone: Icons.event_busy_outlined,
                titulo: 'Nenhum mes disponivel',
                descricao: 'Nao deu para carregar a lista de competencias.',
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: store.opcoes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, indice) {
                    final opcao = store.opcoes[indice];
                    final selecionada = opcao.valor == store.atual;

                    return Material(
                      color: selecionada
                          ? AppColors.primarySurface
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radius),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppSpacing.radius),
                        onTap: () => Navigator.of(context).pop(opcao.valor),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selecionada
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radius),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      store.rotulo(opcao),
                                      style: AppTypography.subtitle,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      store.descricao(opcao),
                                      style: AppTypography.caption
                                          .copyWith(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (selecionada)
                                const Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
