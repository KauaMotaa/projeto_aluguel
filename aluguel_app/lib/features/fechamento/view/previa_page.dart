import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/value_row.dart';
import '../../../data/models/previa.dart';
import '../../../data/repositories/fechamento_repository.dart';
import '../../faturas/view/faturas_page.dart';
import '../viewmodel/previa_viewmodel.dart';

class PreviaPage extends StatelessWidget {
  const PreviaPage({
    super.key,
    required this.imovelId,
    required this.endereco,
  });

  final int imovelId;
  final String endereco;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          PreviaViewModel(ctx.read<FechamentoRepository>(), imovelId: imovelId)
            ..carregar(),
      child: _PreviaView(endereco: endereco),
    );
  }
}

class _PreviaView extends StatelessWidget {
  const _PreviaView({required this.endereco});

  final String endereco;

  /// Vai lancar a fatura e recalcula a previa na volta: o rateio muda
  /// inteiro com ela, e voltar numa tela com numero velho seria pior do
  /// que nao ter o atalho.
  Future<void> _lancarFatura(BuildContext context) async {
    final vm = context.read<PreviaViewModel>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FaturasPage(imovelId: vm.imovelId, endereco: endereco),
      ),
    );
    await vm.carregar();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PreviaViewModel>();
    final previa = vm.previa;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Previa do fechamento',
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
          : previa == null
              ? EmptyState(
                  icone: Icons.calculate_outlined,
                  titulo: 'Nao deu para calcular',
                  descricao: vm.erro,
                  acao: TextButton(
                    onPressed: vm.carregar,
                    child: const Text('Tentar de novo'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (previa.alertas.isNotEmpty) ...[
                      _Alertas(
                        alertas: previa.alertas,
                        onLancarFatura: vm.faltaFatura || vm.faturaIncoerente
                            ? () => _lancarFatura(context)
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.sm + 4),
                    ],
                    if (previa.agua != null && previa.energia != null) ...[
                      _Faturas(
                        vm: vm,
                        previa: previa,
                        onEditar: () => _lancarFatura(context),
                      ),
                      const SizedBox(height: AppSpacing.sm + 4),
                    ],
                    for (final linha in previa.unidades) ...[
                      _CardUnidade(vm: vm, linha: linha),
                      const SizedBox(height: AppSpacing.sm + 4),
                    ],
                  ],
                ),
      bottomNavigationBar: previa == null
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
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(vm.resumoCobrancas,
                              style: AppTypography.caption
                                  .copyWith(fontSize: 13)),
                        ),
                        Text(
                          vm.totalFormatado,
                          style: AppTypography.display.copyWith(fontSize: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppButton.primary(
                      label: 'Confirmar e gerar cobrancas',
                      carregando: vm.fechando,
                      onPressed: vm.podeFechar
                          ? () async {
                              final ok = await vm.fechar();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? '${vm.cobrancasGeradas} cobrancas geradas'
                                      : vm.erro!),
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

class _Alertas extends StatelessWidget {
  const _Alertas({required this.alertas, this.onLancarFatura});

  final List<Alerta> alertas;

  /// Preenchido so quando a pendencia e resolvivel na tela de fatura.
  final VoidCallback? onLancarFatura;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
              const SizedBox(width: 6),
              Text(
                'Pendencias que travam o fechamento',
                style: AppTypography.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final alerta in alertas)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '·  ${alerta.mensagem}',
                style: AppTypography.caption.copyWith(color: AppColors.danger),
              ),
            ),
          if (onLancarFatura != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onLancarFatura,
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('Lancar a fatura agora'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Faturas extends StatelessWidget {
  const _Faturas({
    required this.vm,
    required this.previa,
    required this.onEditar,
  });

  final PreviaViewModel vm;
  final Previa previa;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final agua = previa.agua!;
    final energia = previa.energia!;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'FATURAS DA CONCESSIONARIA',
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              TextButton(
                onPressed: onEditar,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Corrigir'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Fatura(
                  titulo: 'Agua',
                  valor: vm.unitario(agua, 'agua'),
                  origem: vm.origemDaFatura(agua, 'agua'),
                ),
              ),
              Expanded(
                child: _Fatura(
                  titulo: 'Energia',
                  valor: vm.unitario(energia, 'energia'),
                  origem: vm.origemDaFatura(energia, 'energia'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vm.consumoComum(),
                  style: AppTypography.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(vm.rateioExplicado(),
                    style: AppTypography.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fatura extends StatelessWidget {
  const _Fatura({
    required this.titulo,
    required this.valor,
    required this.origem,
  });

  final String titulo;
  final String valor;
  final String origem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: AppTypography.caption),
        const SizedBox(height: 3),
        Text(valor, style: AppTypography.subtitle.copyWith(fontSize: 17)),
        const SizedBox(height: 3),
        Text(origem, style: AppTypography.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _CardUnidade extends StatelessWidget {
  const _CardUnidade({required this.vm, required this.linha});

  final PreviaViewModel vm;
  final LinhaPrevia linha;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(linha.identificacao,
                  style: AppTypography.subtitle.copyWith(fontSize: 15)),
              Flexible(
                child: Text(linha.inquilino,
                    style: AppTypography.caption, textAlign: TextAlign.end),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ValueRow.normal(
            label: 'Aluguel',
            valor: Formatters.moeda(linha.valorAluguel),
          ),
          ValueRow.normal(
            label: vm.parcela(linha.agua, 'agua'),
            valor: Formatters.moeda(linha.agua.valor),
          ),
          ValueRow.normal(
            label: vm.parcela(linha.energia, 'energia'),
            valor: Formatters.moeda(linha.energia.valor),
          ),
          ValueRow.total(
            label: 'Total',
            valor: Formatters.moeda(linha.valorTotal),
          ),
        ],
      ),
    );
  }
}
