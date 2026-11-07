import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/competencia_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/meter_input.dart';
import '../../../data/repositories/leitura_repository.dart';
import '../viewmodel/leituras_viewmodel.dart';

class LeiturasPage extends StatelessWidget {
  const LeiturasPage({
    super.key,
    required this.imovelId,
    required this.endereco,
  });

  final int imovelId;
  final String endereco;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => LeiturasViewModel(
        ctx.read<LeituraRepository>(),
        imovelId: imovelId,
        competencia: ctx.read<CompetenciaStore>().atual,
      )..carregar(),
      child: _LeiturasView(endereco: endereco),
    );
  }
}

class _LeiturasView extends StatelessWidget {
  const _LeiturasView({required this.endereco});

  final String endereco;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LeiturasViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leituras do mes',
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
                  icone: Icons.speed_outlined,
                  titulo: 'Nenhuma unidade ocupada',
                  descricao: vm.erro ??
                      'So unidades com contrato ativo entram no lancamento.',
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    for (final linha in vm.linhas) ...[
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(linha.identificacao,
                                style: AppTypography.subtitle
                                    .copyWith(fontSize: 15)),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: MeterInput(
                                    rotulo: 'Agua (m³)',
                                    tipo: 'agua',
                                    valorAnterior: linha.agua.valorAnterior,
                                    controller: linha.controllerAgua,
                                    erro: linha.erroAgua,
                                    onChanged: (v) =>
                                        vm.validar(linha, 'agua', v),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm + 4),
                                Expanded(
                                  child: MeterInput(
                                    rotulo: 'Energia (kWh)',
                                    tipo: 'energia',
                                    valorAnterior: linha.energia.valorAnterior,
                                    controller: linha.controllerEnergia,
                                    erro: linha.erroEnergia,
                                    onChanged: (v) =>
                                        vm.validar(linha, 'energia', v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
                      label: 'Salvar leituras',
                      carregando: vm.salvando,
                      onPressed: vm.podeSalvar
                          ? () async {
                              final ok = await vm.salvar();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text(ok ? 'Leituras salvas' : vm.erro!),
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
