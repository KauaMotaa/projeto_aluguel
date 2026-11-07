import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/state/competencia_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/repositories/fatura_repository.dart';
import '../viewmodel/faturas_viewmodel.dart';

/// Lancamento das faturas da concessionaria de um ponto.
///
/// Sao duas, uma por medidor geral, e cada uma e um par: o valor da conta
/// e o consumo que o relogio marcou. O rateio divide um pelo outro.
class FaturasPage extends StatelessWidget {
  const FaturasPage({
    super.key,
    required this.imovelId,
    required this.endereco,
  });

  final int imovelId;
  final String endereco;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => FaturasViewModel(
        ctx.read<FaturaRepository>(),
        imovelId: imovelId,
        competencia: ctx.read<CompetenciaStore>().atual,
      )..carregar(),
      child: _FaturasView(endereco: endereco),
    );
  }
}

class _FaturasView extends StatelessWidget {
  const _FaturasView({required this.endereco});

  final String endereco;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FaturasViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fatura da concessionaria',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text(
              '$endereco  ·  ${vm.competenciaFormatada}',
              style: AppTypography.caption.copyWith(
                color: AppColors.onPrimaryMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: vm.carregando
          ? const Center(child: CircularProgressIndicator())
          : vm.linhas.isEmpty
              ? EmptyState(
                  icone: Icons.receipt_outlined,
                  titulo: 'Nao deu para carregar',
                  descricao: vm.erro,
                  acao: TextButton(
                    onPressed: vm.carregar,
                    child: const Text('Tentar de novo'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    const _Explicacao(),
                    const SizedBox(height: AppSpacing.sm + 4),
                    for (final linha in vm.linhas) ...[
                      _CardFatura(vm: vm, linha: linha),
                      const SizedBox(height: AppSpacing.sm + 4),
                    ],
                  ],
                ),
      bottomNavigationBar: vm.linhas.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (vm.avisoRodape != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 15, color: AppColors.danger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              vm.avisoRodape!,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (vm.erro != null) ...[
                      Text(vm.erro!,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.danger)),
                      const SizedBox(height: 10),
                    ],
                    AppButton.primary(
                      label: 'Salvar fatura',
                      carregando: vm.salvando,
                      onPressed: vm.podeSalvar
                          ? () async {
                              final ok = await vm.salvar();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text(ok ? 'Fatura salva' : vm.erro!),
                                ),
                              );
                              if (ok) Navigator.of(context).pop(true);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Explicacao extends StatelessWidget {
  const _Explicacao();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Text(
        'Copie da conta que chegou: o valor total e o consumo que o relogio '
        'geral marcou. O que passar da soma dos submedidores vira area '
        'comum, dividida entre as unidades ocupadas.',
        style: AppTypography.caption.copyWith(fontSize: 12),
      ),
    );
  }
}

class _CardFatura extends StatelessWidget {
  const _CardFatura({required this.vm, required this.linha});

  final FaturasViewModel vm;
  final LinhaFatura linha;

  @override
  Widget build(BuildContext context) {
    final unitario = vm.unitarioDe(linha);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  vm.tituloDe(linha),
                  style: AppTypography.subtitle.copyWith(fontSize: 15),
                ),
              ),
              linha.jaLancada
                  ? StatusBadge.paga(label: vm.statusDe(linha))
                  : StatusBadge.aberta(label: vm.statusDe(linha)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Campo(
                  rotulo: 'Valor total (R\$)',
                  controller: linha.controllerValor,
                  erro: linha.erroValor,
                  legenda: 'Como esta na conta',
                  onChanged: (_) => vm.validar(linha),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: _Campo(
                  rotulo: 'Consumo (${vm.unidadeDe(linha)})',
                  controller: linha.controllerConsumo,
                  erro: linha.erroConsumo,
                  legenda: vm.pisoDe(linha),
                  onChanged: (_) => vm.validar(linha),
                ),
              ),
            ],
          ),
          if (unitario != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Text(
                unitario,
                style: AppTypography.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Campo numerico com rotulo, legenda e erro. Irmao do MeterInput, sem a
/// parte de leitura anterior: aqui nao existe medidor que ande para tras.
class _Campo extends StatelessWidget {
  const _Campo({
    required this.rotulo,
    required this.controller,
    required this.legenda,
    required this.onChanged,
    this.erro,
  });

  final String rotulo;
  final TextEditingController controller;
  final String legenda;
  final ValueChanged<String> onChanged;
  final String? erro;

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
          legenda,
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            color: erro != null ? AppColors.danger : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
