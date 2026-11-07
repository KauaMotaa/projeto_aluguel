import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/value_row.dart';
import '../../../data/models/cobranca.dart';
import '../../../data/repositories/cobranca_repository.dart';
import '../viewmodel/pagamento_viewmodel.dart';

/// Folha de registro de pagamento de uma cobranca.
///
/// E folha, e nao tela cheia, porque o painel e o contexto do gesto: quem
/// registra um recebimento esta olhando a lista de unidades e volta para
/// ela. Uma navegacao inteira para tres campos custaria mais do que rende.
class PagamentoSheet {
  const PagamentoSheet._();

  /// Abre a folha e devolve a mensagem de confirmacao quando um pagamento
  /// foi registrado, ou `null` quando se saiu sem registrar nada. Quem
  /// chama e que recarrega a lista e mostra a mensagem: a folha ja fechou.
  static Future<String?> abrir(
    BuildContext context, {
    required Cobranca cobranca,
  }) {
    final repo = context.read<CobrancaRepository>();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radius + 4),
        ),
      ),
      builder: (_) => ChangeNotifierProvider(
        create: (_) => PagamentoViewModel(repo, cobranca: cobranca),
        child: const _PagamentoView(),
      ),
    );
  }
}

class _PagamentoView extends StatelessWidget {
  const _PagamentoView();

  Future<void> _salvar(BuildContext context) async {
    final vm = context.read<PagamentoViewModel>();
    final salvou = await vm.salvar();
    if (!salvou) return; // o erro fica visivel na propria folha
    if (context.mounted) Navigator.of(context).pop(vm.confirmacao);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PagamentoViewModel>();

    return Padding(
      // Sobe com o teclado: sem isso o campo de valor fica atras dele.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
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
            const Text('Registrar pagamento', style: AppTypography.title),
            const SizedBox(height: 2),
            Text(vm.titulo, style: AppTypography.caption),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: [
                  ValueRow.normal(label: 'Aluguel', valor: vm.aluguelFormatado),
                  ValueRow.normal(label: 'Agua', valor: vm.aguaFormatada),
                  ValueRow.normal(label: 'Energia', valor: vm.energiaFormatada),
                  ValueRow.total(
                    label: 'Total da cobranca',
                    valor: vm.totalFormatado,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${vm.competenciaFormatada}  ·  vence ${vm.vencimentoFormatado}',
              style: AppTypography.caption.copyWith(fontSize: 11),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Valor recebido', style: AppTypography.caption),
            const SizedBox(height: 5),
            TextField(
              controller: vm.controllerValor,
              onChanged: (_) => vm.validar(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: AppTypography.subtitle,
              decoration: InputDecoration(
                prefixText: 'R\$ ',
                prefixStyle: AppTypography.subtitle,
                errorText: vm.erroValor,
              ),
            ),
            if (vm.avisoValor != null) ...[
              const SizedBox(height: 5),
              Text(
                vm.avisoValor!,
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.warning,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            const Text('Forma', style: AppTypography.caption),
            const SizedBox(height: 6),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final entrada in PagamentoViewModel.formas.entries)
                  ChoiceChip(
                    label: Text(entrada.value),
                    selected: vm.forma == entrada.key,
                    onSelected: (_) => vm.escolherForma(entrada.key),
                    showCheckmark: false,
                    labelStyle: AppTypography.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: vm.forma == entrada.key
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primarySurface,
                    side: BorderSide(
                      color: vm.forma == entrada.key
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lancamento em ${vm.dataFormatada}',
              style: AppTypography.caption.copyWith(fontSize: 11),
            ),
            if (vm.erro != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  vm.erro!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.danger,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: 'Registrar pagamento',
              carregando: vm.salvando,
              onPressed: vm.podeSalvar ? () => _salvar(context) : null,
            ),
          ],
        ),
      ),
    );
  }
}
