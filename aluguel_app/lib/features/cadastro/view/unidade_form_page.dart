import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/imovel.dart';
import '../../../data/repositories/cadastro_repository.dart';
import '../viewmodel/unidade_form_viewmodel.dart';

/// Cadastro de uma unidade nova num ponto que ja existe.
class UnidadeFormPage extends StatelessWidget {
  const UnidadeFormPage({
    super.key,
    required this.imoveis,
    required this.existentes,
  });

  final List<Imovel> imoveis;

  /// Identificacoes ja em uso, por imovel. O painel acabou de carregar
  /// isso, entao vem pronto em vez de a tela pedir de novo.
  final Map<int, List<String>> existentes;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => UnidadeFormViewModel(
        ctx.read<CadastroRepository>(),
        imoveis: imoveis,
        existentes: existentes,
      ),
      child: const _UnidadeFormView(),
    );
  }
}

class _UnidadeFormView extends StatelessWidget {
  const _UnidadeFormView();

  Future<void> _salvar(BuildContext context) async {
    final vm = context.read<UnidadeFormViewModel>();
    final salvou = await vm.salvar();
    if (!salvou || !context.mounted) return;
    Navigator.of(context).pop(vm.confirmacao);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UnidadeFormViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nova unidade',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Text('Ponto', style: AppTypography.caption),
          const SizedBox(height: 5),
          DropdownButtonFormField<int>(
            initialValue: vm.imovelId,
            items: [
              for (final imovel in vm.imoveis)
                DropdownMenuItem(
                  value: imovel.id,
                  child: Text(imovel.endereco, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) {
              if (id != null) vm.escolherImovel(id);
            },
          ),
          const SizedBox(height: 5),
          Text(
            vm.resumoDoImovel,
            style: AppTypography.caption.copyWith(fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Identificacao', style: AppTypography.caption),
          const SizedBox(height: 5),
          TextField(
            controller: vm.controllerIdentificacao,
            onChanged: (_) => vm.validar(),
            textCapitalization: TextCapitalization.words,
            style: AppTypography.subtitle,
            decoration: InputDecoration(
              hintText: 'Kitnet 05',
              errorText: vm.erroIdentificacao,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'E o nome que aparece no painel e na cobranca',
            style: AppTypography.caption.copyWith(fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'A unidade nasce vaga. O aluguel e o inquilino entram '
                    'pelo contrato, no card dela no painel.',
                    style: AppTypography.caption.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (vm.erro != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Erro(mensagem: vm.erro!),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton.primary(
            label: 'Cadastrar unidade',
            carregando: vm.salvando,
            onPressed: vm.podeSalvar ? () => _salvar(context) : null,
          ),
        ],
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Text(
        mensagem,
        style: AppTypography.caption.copyWith(
          color: AppColors.danger,
          fontSize: 12,
        ),
      ),
    );
  }
}
