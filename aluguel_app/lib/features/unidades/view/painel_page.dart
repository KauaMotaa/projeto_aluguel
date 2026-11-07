import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/competencia_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/unidade.dart';
import '../../auth/view/login_page.dart';
import '../../cadastro/view/contrato_form_page.dart';
import '../../cadastro/view/unidade_form_page.dart';
import '../../cobrancas/view/pagamento_sheet.dart';
import '../../fechamento/view/previa_page.dart';
import '../../leituras/view/leituras_page.dart';
import '../viewmodel/painel_viewmodel.dart';
import 'competencia_sheet.dart';

class PainelPage extends StatefulWidget {
  const PainelPage({super.key});

  @override
  State<PainelPage> createState() => _PainelPageState();
}

class _PainelPageState extends State<PainelPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrir());
  }

  /// A lista de meses vem antes dos dados: o painel carrega a competencia
  /// que o store escolher, e enquanto a lista nao chega o mes seria o do
  /// relogio do aparelho, que pode nem ter lancamento.
  Future<void> _abrir() async {
    await context.read<CompetenciaStore>().carregar();
    if (mounted) await context.read<PainelViewModel>().carregar();
  }

  Future<void> _trocarCompetencia() async {
    final mudou = await CompetenciaSheet.abrir(context);
    if (mudou && mounted) {
      await context.read<PainelViewModel>().carregar();
    }
  }

  /// Registra o recebimento de uma cobranca e recarrega: o status, o
  /// subtotal do ponto e a linha de recebido mudam todos com ele.
  Future<void> _receber(Unidade unidade) async {
    final vm = context.read<PainelViewModel>();
    final cobranca = vm.cobrancaDa(unidade);
    if (cobranca == null) return;

    final mensagem = await PagamentoSheet.abrir(context, cobranca: cobranca);
    if (mensagem == null || !mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
    await vm.carregar();
  }

  /// Cadastra uma unidade nova. A lista de pontos e as identificacoes ja
  /// usadas saem do painel, que acabou de carregar as duas coisas.
  Future<void> _novaUnidade() async {
    final vm = context.read<PainelViewModel>();
    final mensagem = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => UnidadeFormPage(
          imoveis: vm.imoveis,
          existentes: vm.identificacoesPorImovel,
        ),
      ),
    );
    if (mensagem == null || !mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
    await vm.carregar();
  }

  /// Aluga uma unidade vaga. O gesto comeca no card dela porque e ali que
  /// se ve que esta vazia.
  Future<void> _alugar(Unidade unidade, String endereco) async {
    final vm = context.read<PainelViewModel>();
    final mensagem = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ContratoFormPage(
          unidade: unidade,
          endereco: endereco,
        ),
      ),
    );
    if (mensagem == null || !mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
    await vm.carregar();
  }

  Future<void> _sair() async {
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
          _Cabecalho(
            vm: vm,
            onTrocarCompetencia: _trocarCompetencia,
            onSair: _sair,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: vm.carregar,
              child: _corpo(vm),
            ),
          ),
        ],
      ),
      // Sem ponto cadastrado nao ha onde pendurar uma unidade, e o botao
      // levaria para um seletor vazio.
      floatingActionButton: vm.imoveis.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _novaUnidade,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Nova unidade'),
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
            _CardUnidade(
              unidade: unidade,
              vm: vm,
              // O card e a porta das duas acoes da unidade: cobranca
              // aberta leva ao recebimento, unidade vaga leva ao
              // contrato. Nenhuma das duas, e ele fica parado.
              onToque: vm.podeReceber(unidade)
                  ? () => _receber(unidade)
                  : unidade.ocupada
                      ? null
                      : () => _alugar(unidade, grupo.imovel.endereco),
            ),
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
  const _Cabecalho({
    required this.vm,
    required this.onTrocarCompetencia,
    required this.onSair,
  });

  final PainelViewModel vm;
  final VoidCallback onTrocarCompetencia;
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
                    // O mes e o unico filtro do painel inteiro, entao ele e
                    // o proprio titulo: toca e troca.
                    InkWell(
                      onTap: onTrocarCompetencia,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right: AppSpacing.xs,
                          bottom: 2,
                        ),
                        child: Row(
                          children: [
                            Text(
                              vm.competenciaFormatada,
                              style: AppTypography.title
                                  .copyWith(color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.expand_more,
                              size: 20,
                              color: AppColors.onPrimaryMuted,
                            ),
                          ],
                        ),
                      ),
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
            'Faturado neste mes  ·  ${vm.resumoPontos}',
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
          if (vm.resumoRecebimento != null) ...[
            const SizedBox(height: 6),
            Text(
              vm.resumoRecebimento!,
              style: AppTypography.caption.copyWith(
                color: AppColors.onPrimaryMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardUnidade extends StatelessWidget {
  const _CardUnidade({
    required this.unidade,
    required this.vm,
    this.onToque,
  });

  final Unidade unidade;
  final PainelViewModel vm;

  /// Nulo quando nao ha nada a fazer com a unidade: ocupada e com o mes
  /// ainda nao fechado, ou com a cobranca ja paga. Um card clicavel que
  /// nao faz nada e pior que um parado.
  final VoidCallback? onToque;

  @override
  Widget build(BuildContext context) {
    final valor = vm.valorDaUnidade(unidade);

    return AppCard(
      onTap: onToque,
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
          if (onToque != null) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );
  }
}
