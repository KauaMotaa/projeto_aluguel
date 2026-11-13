import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/texto_cobranca.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/value_row.dart';
import '../../../data/models/cobranca.dart';
import '../../../data/models/consumo.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/inquilino_repository.dart';
import '../../auth/view/login_page.dart';
import '../viewmodel/inquilino_viewmodel.dart';
import 'aviso_pagamento_sheet.dart';

/// Painel do inquilino: o que ele deve e quanto consumiu.
///
/// O ViewModel e local a tela, num ChangeNotifierProvider proprio, porque
/// nada fora daqui le esse estado.
class InquilinoPage extends StatelessWidget {
  const InquilinoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => InquilinoViewModel(
        ctx.read<InquilinoRepository>(),
        ctx.read<AuthRepository>(),
      )..carregar(),
      child: const _InquilinoView(),
    );
  }
}

class _InquilinoView extends StatelessWidget {
  const _InquilinoView();

  /// Manda o aviso e recarrega: a cobranca volta com o recado anexado, e
  /// o card passa a mostrar que ha algo aguardando conferencia.
  Future<void> _avisar(BuildContext context, Cobranca cobranca) async {
    final vm = context.read<InquilinoViewModel>();
    final mensagem = await AvisoPagamentoSheet.abrir(context, cobranca: cobranca);
    if (mensagem == null || !context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
    await vm.carregar();
  }

  Future<void> _sair(BuildContext context) async {
    context.read<InquilinoViewModel>().sair();
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InquilinoViewModel>();

    return Scaffold(
      body: Column(
        children: [
          _Cabecalho(vm: vm, onSair: () => _sair(context)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: vm.carregar,
              child: _corpo(context, vm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corpo(BuildContext context, InquilinoViewModel vm) {
    if (vm.carregando && vm.cobrancas.isEmpty && vm.consumo.isEmpty) {
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

    if (vm.cobrancas.isEmpty && vm.consumo.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 60),
          EmptyState(
            icone: Icons.receipt_long_outlined,
            titulo: 'Nada por aqui ainda',
            descricao: 'Suas cobrancas aparecem quando o proprietario '
                'fechar o mes.',
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
        const _Titulo(
          texto: 'Minhas cobrancas',
          icone: Icons.receipt_long_outlined,
        ),
        if (vm.explicacaoDoRateio != null) ...[
          const SizedBox(height: 2),
          Text(
            vm.explicacaoDoRateio!,
            style: AppTypography.caption.copyWith(fontSize: 11),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (vm.cobrancas.isEmpty)
          AppCard(
            child: Text(
              'Nenhuma cobranca fechada ate agora.',
              style: AppTypography.caption.copyWith(fontSize: 13),
            ),
          )
        else
          for (final cobranca in vm.cobrancas) ...[
            _CardCobranca(
              vm: vm,
              cobranca: cobranca,
              onAvisar: vm.podeAvisar(cobranca)
                  ? () => _avisar(context, cobranca)
                  : null,
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: AppSpacing.md),
        const _Titulo(texto: 'Meu consumo', icone: Icons.show_chart_outlined),
        const SizedBox(height: AppSpacing.sm),
        for (final unidade in vm.consumo) ...[
          _CardConsumo(vm: vm, consumo: unidade),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.vm, required this.onSair});

  final InquilinoViewModel vm;
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
                      'INQUILINO',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.onPrimaryMuted,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vm.nome,
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
            vm.resumoCabecalho,
            style: AppTypography.body.copyWith(
              color: AppColors.onPrimaryMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            vm.valorCabecalho,
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

class _Titulo extends StatelessWidget {
  const _Titulo({required this.texto, required this.icone});

  final String texto;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        children: [
          Icon(icone, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            texto,
            style: AppTypography.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardCobranca extends StatelessWidget {
  const _CardCobranca({
    required this.vm,
    required this.cobranca,
    this.onAvisar,
  });

  final InquilinoViewModel vm;
  final Cobranca cobranca;

  /// Nulo em cobranca ja paga: nao ha o que avisar.
  final VoidCallback? onAvisar;

  /// Cobranca antiga pode nao ter a quebra guardada. Nesse caso mostra so
  /// o total, em vez de inventar de onde ele veio.
  static ValueRow _linhaDeConsumo(InquilinoViewModel vm, Cobranca cobranca,
      String tipo, String label, String valor) {
    final origem = vm.origemDe(cobranca, tipo);
    if (origem == null) return ValueRow.normal(label: label, valor: valor);
    return ValueRow.comOrigem(label: label, valor: valor, origem: origem);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      destaque: cobranca.atrasada,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vm.competenciaDe(cobranca),
                        style: AppTypography.subtitle),
                    const SizedBox(height: 3),
                    Text(
                      vm.legendaDe(cobranca),
                      style: AppTypography.caption.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge.doStatus(cobranca.status),
              // O inquilino guarda o proprio comprovante com o mesmo
              // texto que o dono manda: a quebra inteira, nao so o total.
              IconButton(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: TextoCobranca.corpo(cobranca),
                    subject: TextoCobranca.assunto(cobranca),
                  ),
                ),
                tooltip: 'Compartilhar',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.share_outlined, size: 18),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          ValueRow.normal(label: 'Aluguel', valor: vm.aluguelDe(cobranca)),
          _linhaDeConsumo(vm, cobranca, 'agua', 'Agua', vm.aguaDe(cobranca)),
          _linhaDeConsumo(
              vm, cobranca, 'energia', 'Energia', vm.energiaDe(cobranca)),
          ValueRow.total(label: 'Total', valor: vm.totalDe(cobranca)),
          if (vm.avisoEnviadoDe(cobranca) != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule_outlined,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    vm.avisoEnviadoDe(cobranca)!,
                    style: AppTypography.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (onAvisar != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onAvisar,
                icon: const Icon(Icons.check_circle_outline, size: 17),
                label: Text(vm.rotuloDoAviso(cobranca)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardConsumo extends StatelessWidget {
  const _CardConsumo({required this.vm, required this.consumo});

  final InquilinoViewModel vm;
  final Consumo consumo;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(consumo.identificacao, style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.sm + 2),
          const _LinhaConsumo(
            mes: 'MES',
            agua: 'AGUA',
            energia: 'ENERGIA',
            cabecalho: true,
          ),
          if (consumo.historico.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Sem leitura lancada ainda.',
                style: AppTypography.caption.copyWith(fontSize: 13),
              ),
            )
          else
            for (final ponto in consumo.historico)
              _LinhaConsumo(
                mes: vm.mesDe(ponto),
                agua: vm.aguaConsumidaDe(ponto),
                energia: vm.energiaConsumidaDe(ponto),
              ),
        ],
      ),
    );
  }
}

/// Uma linha da tabela de consumo. As duas colunas de valor tem largura
/// fixa para os numeros ficarem alinhados entre os meses.
class _LinhaConsumo extends StatelessWidget {
  const _LinhaConsumo({
    required this.mes,
    required this.agua,
    required this.energia,
    this.cabecalho = false,
  });

  final String mes;
  final String agua;
  final String energia;
  final bool cabecalho;

  @override
  Widget build(BuildContext context) {
    final estilo = cabecalho
        ? AppTypography.caption.copyWith(fontSize: 10, letterSpacing: 0.5)
        : AppTypography.body.copyWith(fontSize: 13);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: cabecalho
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              mes,
              style: cabecalho
                  ? estilo
                  : estilo.copyWith(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 78,
            child: Text(agua, textAlign: TextAlign.right, style: estilo),
          ),
          SizedBox(
            width: 78,
            child: Text(energia, textAlign: TextAlign.right, style: estilo),
          ),
        ],
      ),
    );
  }
}
