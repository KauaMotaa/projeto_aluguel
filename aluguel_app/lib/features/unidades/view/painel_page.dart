import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/unidade.dart';
import '../../auth/view/login_page.dart';
import '../../fechamento/view/previa_page.dart';
import '../../leituras/view/leituras_page.dart';
import '../viewmodel/painel_viewmodel.dart';

class PainelPage extends StatefulWidget {
  const PainelPage({super.key});

  @override
  State<PainelPage> createState() => _PainelPageState();
}

class _PainelPageState extends State<PainelPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PainelViewModel>().carregar(),
    );
  }

  Future<void> _sair(BuildContext context) async {
    context.read<PainelViewModel>().sair();
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PainelViewModel>();

    return Scaffold(
      body: Column(
        children: [
          _Cabecalho(vm: vm, onSair: () => _sair(context)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: vm.carregar,
              child: _corpo(vm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corpo(PainelViewModel vm) {
    if (vm.carregando && vm.grupos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.erro != null) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          EmptyState(
            icone: Icons.wifi_off_outlined,
            titulo: 'Nao deu para carregar',
            descricao: vm.erro,
            acao: TextButton(
              onPressed: vm.carregar,
              child: const Text('Tentar de novo'),
            ),
          ),
        ],
      );
    }

    if (vm.grupos.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 60),
          EmptyState(
            icone: Icons.home_work_outlined,
            titulo: 'Nenhum imovel cadastrado',
            descricao: 'Cadastre um ponto para comecar.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        for (final grupo in vm.grupos) ...[
          SectionHeader(
            endereco: grupo.imovel.endereco,
            valor: grupo.subtotal > 0 ? grupo.subtotalFormatado : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final unidade in grupo.unidades) ...[
            _CardUnidade(unidade: unidade, vm: vm),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LeiturasPage(
                        imovelId: grupo.imovel.id,
                        endereco: grupo.imovel.endereco,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.speed_outlined, size: 18),
                  label: const Text('Leituras'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PreviaPage(
                        imovelId: grupo.imovel.id,
                        endereco: grupo.imovel.endereco,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.calculate_outlined, size: 18),
                  label: const Text('Fechar mes'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.vm, required this.onSair});

  final PainelViewModel vm;
  final VoidCallback onSair;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.of(context).padding.top + AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMPETENCIA',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.onPrimaryMuted,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vm.competenciaFormatada,
                      style: AppTypography.title.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onSair,
                tooltip: 'Sair',
                icon: const Icon(Icons.logout, size: 20),
                color: AppColors.onPrimaryMuted,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'A receber neste mes  ·  ${vm.resumoPontos}',
            style: AppTypography.body.copyWith(
              color: AppColors.onPrimaryMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            vm.totalFormatado,
            style: AppTypography.display.copyWith(
              color: Colors.white,
              fontSize: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardUnidade extends StatelessWidget {
  const _CardUnidade({required this.unidade, required this.vm});

  final Unidade unidade;
  final PainelViewModel vm;

  @override
  Widget build(BuildContext context) {
    final valor = vm.valorDaUnidade(unidade);

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unidade.identificacao,
                  style: AppTypography.subtitle.copyWith(
                    color: unidade.ocupada
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(vm.legendaDaUnidade(unidade),
                    style: AppTypography.caption.copyWith(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (valor.isNotEmpty) ...[
                Text(valor, style: AppTypography.subtitle),
                const SizedBox(height: 6),
              ],
              unidade.ocupada
                  ? StatusBadge.doStatus(unidade.cobrancaStatus)
                  : StatusBadge.vaga(),
            ],
          ),
        ],
      ),
    );
  }
}
