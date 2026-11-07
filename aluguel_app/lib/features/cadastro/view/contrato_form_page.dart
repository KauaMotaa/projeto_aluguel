import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/unidade.dart';
import '../../../data/repositories/cadastro_repository.dart';
import '../viewmodel/contrato_form_viewmodel.dart';

/// Contrato de aluguel de uma unidade vaga.
class ContratoFormPage extends StatelessWidget {
  const ContratoFormPage({
    super.key,
    required this.unidade,
    required this.endereco,
  });

  final Unidade unidade;
  final String endereco;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ContratoFormViewModel(
        ctx.read<CadastroRepository>(),
        unidade: unidade,
      )..carregar(),
      child: _ContratoFormView(endereco: endereco),
    );
  }
}

class _ContratoFormView extends StatelessWidget {
  const _ContratoFormView({required this.endereco});

  final String endereco;

  Future<void> _salvar(BuildContext context) async {
    final vm = context.read<ContratoFormViewModel>();
    final salvou = await vm.salvar();
    if (!salvou || !context.mounted) return;
    Navigator.of(context).pop(vm.confirmacao);
  }

  Future<void> _escolherData(BuildContext context) async {
    final vm = context.read<ContratoFormViewModel>();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: vm.dataInicio,
      firstDate: DateTime(vm.dataInicio.year - 3),
      lastDate: DateTime(vm.dataInicio.year + 3),
      helpText: 'Inicio do contrato',
    );
    if (escolhida != null) vm.escolherDataInicio(escolhida);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ContratoFormViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vm.titulo,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              endereco,
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
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const Text('Inquilino', style: AppTypography.caption),
                const SizedBox(height: 5),
                if (vm.inquilinos.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    initialValue: vm.inquilinoId,
                    hint: const Text('Escolha quem vai morar'),
                    items: [
                      for (final pessoa in vm.inquilinos)
                        DropdownMenuItem(
                          value: pessoa.id,
                          child: Text(
                            pessoa.alojado
                                ? '${pessoa.nome}  (${pessoa.unidades.join(', ')})'
                                : pessoa.nome,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null) vm.escolherInquilino(id);
                    },
                  ),
                  if (vm.avisoInquilino != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      vm.avisoInquilino!,
                      style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: vm.cadastrarNovo,
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: const Text('Cadastrar uma pessoa nova'),
                    ),
                  ),
                ],
                if (vm.novoInquilino) ...[
                  if (vm.inquilinos.isEmpty)
                    Text(
                      'Nenhuma pessoa cadastrada ainda',
                      style: AppTypography.caption.copyWith(fontSize: 11),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: vm.controllerNome,
                    onChanged: (_) => vm.validar(),
                    textCapitalization: TextCapitalization.words,
                    style: AppTypography.subtitle,
                    decoration: InputDecoration(
                      labelText: 'Nome',
                      errorText: vm.erroNome,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: vm.controllerTelefone,
                    keyboardType: TextInputType.phone,
                    style: AppTypography.subtitle,
                    decoration: const InputDecoration(
                      labelText: 'Telefone (opcional)',
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const Text('Valor do aluguel', style: AppTypography.caption),
                const SizedBox(height: 5),
                TextField(
                  controller: vm.controllerValor,
                  onChanged: (_) => vm.validar(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: AppTypography.subtitle,
                  decoration: InputDecoration(
                    prefixText: 'R\$ ',
                    prefixStyle: AppTypography.subtitle,
                    hintText: '650,00',
                    errorText: vm.erroValor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'So o aluguel. Agua e energia entram pelo rateio do mes.',
                  style: AppTypography.caption.copyWith(fontSize: 11),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dia do vencimento',
                              style: AppTypography.caption),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<int>(
                            initialValue: vm.diaVencimento,
                            items: [
                              for (final dia
                                  in ContratoFormViewModel.diasVencimento)
                                DropdownMenuItem(
                                  value: dia,
                                  child: Text('Dia $dia'),
                                ),
                            ],
                            onChanged: (dia) {
                              if (dia != null) vm.escolherDia(dia);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Inicio', style: AppTypography.caption),
                          const SizedBox(height: 5),
                          OutlinedButton(
                            onPressed: () => _escolherData(context),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              side: const BorderSide(
                                color: AppColors.borderStrong,
                              ),
                              foregroundColor: AppColors.textPrimary,
                            ),
                            child: Text(
                              vm.dataInicioFormatada,
                              style: AppTypography.body,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  destaque: true,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_available_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          vm.resumoVencimento,
                          style: AppTypography.caption.copyWith(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (vm.erro != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding:
                        const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSurface,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
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
                const SizedBox(height: AppSpacing.xl),
                AppButton.primary(
                  label: 'Criar contrato',
                  carregando: vm.salvando,
                  onPressed: vm.podeSalvar ? () => _salvar(context) : null,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
    );
  }
}
