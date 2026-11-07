import 'package:aluguel_app/data/models/cobranca.dart';
import 'package:aluguel_app/data/repositories/cobranca_repository.dart';
import 'package:aluguel_app/features/cobrancas/viewmodel/pagamento_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/api_falsa.dart';

void main() {
  final cobranca = Cobranca.fromJson(cobrancaJson(
    7,
    aluguel: 65000,
    agua: 12534,
    energia: 23581,
  ));

  /// Total da cobranca do cenario: R$ 1.011,15.
  const total = 65000 + 12534 + 23581;

  PagamentoViewModel montar(ApiFalsa api) => PagamentoViewModel(
        CobrancaRepository(api.cliente),
        cobranca: cobranca,
        hoje: DateTime(2026, 11, 7),
      );

  ApiFalsa aceita({String status = 'paga', int valor = total}) => ApiFalsa({
        'POST /cobrancas/7/pagamento': {
          'id': 1,
          'cobranca_id': 7,
          'valor': valor,
          'data_pagamento': '2026-11-07',
          'forma': 'pix',
          'cobranca_status': status,
        },
      });

  test('abre com o total preenchido, que e o caso normal', () {
    final vm = montar(aceita());

    expect(vm.centavos, total);
    expect(vm.controllerValor.text, '1.011,15');
    expect(vm.totalFormatado, r'R$ 1.011,15');
    expect(vm.avisoValor, isNull);
    expect(vm.podeSalvar, isTrue);
  });

  test('valor menor avisa que a cobranca fica aberta pela diferenca', () {
    final vm = montar(aceita());

    vm.controllerValor.text = '500,00';
    vm.validar();

    expect(vm.erroValor, isNull, reason: 'parcial e valido, nao e erro');
    expect(vm.avisoValor, r'Pagamento parcial: a cobranca fica aberta por R$ 511,15');
    expect(vm.podeSalvar, isTrue);
  });

  test('valor maior avisa que quita mesmo assim', () {
    final vm = montar(aceita());

    vm.controllerValor.text = '1.100,00';
    vm.validar();

    expect(vm.avisoValor, contains(r'Acima do total em R$ 88,85'));
  });

  test('zero e texto invalido barram o botao', () {
    final vm = montar(aceita());

    vm.controllerValor.text = '0';
    vm.validar();
    expect(vm.erroValor, 'Precisa ser maior que zero');
    expect(vm.podeSalvar, isFalse);

    vm.controllerValor.text = '';
    vm.validar();
    expect(vm.erroValor, 'Informe o valor recebido');
    expect(vm.podeSalvar, isFalse);
  });

  test('manda centavos, data de hoje e a forma escolhida', () async {
    final api = aceita();
    final vm = montar(api);

    vm.escolherForma('dinheiro');
    expect(await vm.salvar(), isTrue);

    expect(api.corpoDe('POST /cobrancas/7/pagamento'), {
      'valor': total,
      'data_pagamento': '2026-11-07',
      'forma': 'dinheiro',
    });
  });

  test('quem diz se quitou e a API, nao o app', () async {
    // O valor cobre o total, mas a API responde que a cobranca segue
    // aberta: havia um estorno, outro lancamento, o que for. O app
    // repete o que ela disse.
    final vm = montar(aceita(status: 'aberta'));

    await vm.salvar();

    expect(vm.pagamento!.quitou, isFalse);
    expect(vm.confirmacao, contains('cobranca segue aberta'));
  });

  test('cobranca quitada confirma com o nome da unidade', () async {
    final vm = montar(aceita());

    await vm.salvar();

    expect(vm.confirmacao, 'Kitnet 01: cobranca quitada');
  });

  test('cobranca ja paga devolve 409 e a mensagem fica na folha', () async {
    final api = ApiFalsa({
      'POST /cobrancas/7/pagamento': const Falha(409, 'Cobranca ja esta paga'),
    });
    final vm = montar(api);

    expect(await vm.salvar(), isFalse);
    expect(vm.erro, 'Cobranca ja esta paga');
    expect(vm.salvando, isFalse);
  });

  test('a forma comeca em pix e so muda para uma que a API aceita', () {
    final vm = montar(aceita());

    expect(vm.forma, 'pix');
    vm.escolherForma('cartao');
    expect(vm.forma, 'pix', reason: 'a API nao conhece cartao');
    vm.escolherForma('transferencia');
    expect(vm.forma, 'transferencia');
  });
}
