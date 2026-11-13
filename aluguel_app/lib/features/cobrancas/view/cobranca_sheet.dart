import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/forma_pagamento.dart';
import '../../../core/widgets/value_row.dart';
import '../../../data/models/cobranca.dart';
import '../../../data/repositories/cobranca_repository.dart';
import '../viewmodel/cobranca_viewmodel.dart';

/// Folha de uma cobranca: compartilhar com o inquilino e receber.
///
/// E folha, e nao tela cheia, porque o painel e o contexto do gesto: quem
/// registra um recebimento esta olhando a lista de unidades e volta para
/// ela. Uma navegacao inteira para tres campos custaria mais do que rende.
///
/// Quitada, ela mostra so a quebra e o botao de compartilhar — a rota de
/// pagamento recusa cobranca paga com 409, e oferecer um botao que so
/// serve para dar erro e pior do que nao oferecer.
class CobrancaSheet {
  const CobrancaSheet._();

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
        create: (_) => CobrancaViewModel(repo, cobranca: cobranca),
        child: const _CobrancaView(),
      ),
    );
  }
}

class _CobrancaView extends StatelessWidget {
  const _CobrancaView();

  Future<void> _salvar(BuildContext context) async {
    final vm = context.read<CobrancaViewModel>();
    final salvou = await vm.salvar();
    if (!salvou) return; // o erro fica visivel na propria folha
    if (context.mounted) Navigator.of(context).pop(vm.confirmacao);
  }

  /// Entrega o texto ao menu de compartilhar do sistema. A folha fica
  /// aberta: quem compartilhou pode querer registrar o pagamento em
  /// seguida, e fechar aqui obrigaria a tocar no card de novo.
  Future<void> _compartilhar(BuildContext context) async {
    final vm = context.read<CobrancaViewModel>();
    await SharePlus.instance.share(
      ShareParams(
        text: vm.textoParaCompartilhar,
        subject: vm.assuntoParaCompartilhar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CobrancaViewModel>();

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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vm.quitada ? 'Cobranca paga' : 'Cobranca em aberto',
                        style: AppTypography.title,
                      ),
                      const SizedBox(height: 2),
                      Text(vm.titulo, style: AppTypography.caption),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _compartilhar(context),
                  tooltip: 'Compartilhar',
                  icon: const Icon(Icons.share_outlined, size: 20),
                  color: AppColors.primary,
                ),
              ],
            ),
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
              vm.quitada
                  ? vm.competenciaFormatada
                  : '${vm.competenciaFormatada}  ·  vence ${vm.vencimentoFormatado}',
              style: AppTypography.caption.copyWith(fontSize: 11),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.secondary(
              label: 'Compartilhar com o inquilino',
              onPressed: () => _compartilhar(context),
            ),
            // Paga nao tem o que receber: a rota de pagamento devolve 409.
            if (vm.quitada) const SizedBox(height: AppSpacing.sm),
            if (!vm.quitada) ...[
              if (vm.avisoDoInquilino != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  destaque: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.mark_email_read_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${vm.avisoDoInquilino!} Confira e lance abaixo.',
                          style: AppTypography.caption.copyWith(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
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
            FormaPagamento(
              formas: CobrancaViewModel.formas,
              selecionada: vm.forma,
              onEscolher: vm.escolherForma,
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
          ],
        ),
      ),
    );
  }
}
