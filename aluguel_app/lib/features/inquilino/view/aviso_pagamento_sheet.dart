import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/forma_pagamento.dart';
import '../../../data/models/cobranca.dart';
import '../../../data/repositories/inquilino_repository.dart';
import '../viewmodel/aviso_pagamento_viewmodel.dart';

/// Folha do inquilino avisando que pagou.
class AvisoPagamentoSheet {
  const AvisoPagamentoSheet._();

  /// Abre a folha e devolve a mensagem de confirmacao quando o aviso foi
  /// enviado, ou `null` quando se saiu sem enviar.
  static Future<String?> abrir(
    BuildContext context, {
    required Cobranca cobranca,
  }) {
    final repo = context.read<InquilinoRepository>();

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
        create: (_) => AvisoPagamentoViewModel(repo, cobranca: cobranca),
        child: const _AvisoView(),
      ),
    );
  }
}

class _AvisoView extends StatelessWidget {
  const _AvisoView();

  Future<void> _enviar(BuildContext context) async {
    final vm = context.read<AvisoPagamentoViewModel>();
    final enviou = await vm.salvar();
    if (!enviou) return; // o erro fica visivel na propria folha
    if (context.mounted) Navigator.of(context).pop(vm.confirmacao);
  }

  Future<void> _escolherData(BuildContext context) async {
    final vm = context.read<AvisoPagamentoViewModel>();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: vm.data,
      firstDate: DateTime(vm.ultimoDiaValido.year - 1),
      // Nao da para ter pago amanha.
      lastDate: vm.ultimoDiaValido,
      helpText: 'Quando voce pagou',
    );
    if (escolhida != null) vm.escolherData(escolhida);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AvisoPagamentoViewModel>();

    return Padding(
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
            Text(vm.titulo, style: AppTypography.title),
            const SizedBox(height: 2),
            Text(vm.subtitulo, style: AppTypography.caption),
            const SizedBox(height: AppSpacing.md),
            // A frase que evita o mal-entendido de quem aperta o botao
            // achando que a cobranca vai ficar paga na hora.
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Text(
                'Isto avisa o proprietario. A cobranca so fica paga quando '
                'ele confirmar o recebimento.',
                style: AppTypography.caption.copyWith(fontSize: 12),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Quanto voce pagou', style: AppTypography.caption),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quando', style: AppTypography.caption),
                      const SizedBox(height: 5),
                      OutlinedButton(
                        onPressed: () => _escolherData(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: AppColors.borderStrong),
                          foregroundColor: AppColors.textPrimary,
                        ),
                        child: Text(vm.dataFormatada,
                            style: AppTypography.body),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Como', style: AppTypography.caption),
            const SizedBox(height: 6),
            FormaPagamento(
              formas: AvisoPagamentoViewModel.formas,
              selecionada: vm.forma,
              onEscolher: vm.escolherForma,
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
              label: vm.corrigindo ? 'Corrigir o aviso' : 'Avisar o proprietario',
              carregando: vm.salvando,
              onPressed: vm.podeSalvar ? () => _enviar(context) : null,
            ),
          ],
        ),
      ),
    );
  }
}
