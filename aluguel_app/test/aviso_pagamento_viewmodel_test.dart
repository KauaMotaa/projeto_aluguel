import 'package:aluguel_app/data/models/cobranca.dart';
import 'package:aluguel_app/data/repositories/inquilino_repository.dart';
import 'package:aluguel_app/features/inquilino/viewmodel/aviso_pagamento_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/api_falsa.dart';

void main() {
  const total = 65000 + 12533 + 23580; // R$ 1.011,13

  Cobranca cobranca({Map<String, Object?>? aviso, String status = 'aberta'}) =>
      Cobranca.fromJson(cobrancaJson(
        7,
        aluguel: 65000,
        agua: 12533,
        energia: 23580,
        status: status,
        pagamentoInformado: aviso,
      ));

  AvisoPagamentoViewModel montar(ApiFalsa api, {Map<String, Object?>? aviso}) =>
      AvisoPagamentoViewModel(
        InquilinoRepository(api.cliente),
        cobranca: cobranca(aviso: aviso),
        hoje: DateTime(2026, 11, 13),
      );

  ApiFalsa aceita({Map<String, Object?>? devolve}) => ApiFalsa({
        'POST /minhas-cobrancas/7/aviso-pagamento': devolve ??
            cobrancaJson(
              7,
              aluguel: 65000,
              agua: 12533,
              energia: 23580,
              pagamentoInformado: avisoJson(valor: total),
            ),
      });

  test('abre com o total e a data de hoje', () {
    final vm = montar(aceita());

    expect(vm.centavos, total);
    expect(vm.controllerValor.text, '1.011,13');
    expect(vm.dataIso, '2026-11-13');
    expect(vm.forma, 'pix');
    expect(vm.titulo, 'Avisar que paguei');
    expect(vm.corrigindo, isFalse);
  });

  test('ja tendo avisado, abre com o que foi informado antes', () {
    final vm = montar(
      aceita(),
      aviso: avisoJson(
          valor: 50000, dataPagamento: '2026-11-10', forma: 'dinheiro'),
    );

    expect(vm.corrigindo, isTrue);
    expect(vm.titulo, 'Corrigir o aviso');
    expect(vm.centavos, 50000);
    expect(vm.dataIso, '2026-11-10');
    expect(vm.forma, 'dinheiro');
  });

  test('valor diferente do total avisa, mas deixa enviar', () {
    final vm = montar(aceita());

    vm.controllerValor.text = '500,00';
    vm.validar();

    expect(vm.erroValor, isNull);
    expect(vm.avisoValor, r'Faltam R$ 511,13 para o total de R$ 1.011,13.');
    expect(vm.podeSalvar, isTrue, reason: 'pagamento parcial e combinavel');
  });

  test('valor em branco ou zero barra o botao', () {
    final vm = montar(aceita());

    vm.controllerValor.text = '';
    vm.validar();
    expect(vm.erroValor, 'Informe quanto voce pagou');
    expect(vm.podeSalvar, isFalse);

    vm.controllerValor.text = '0';
    vm.validar();
    expect(vm.erroValor, 'Precisa ser maior que zero');
  });

  test('nao da para ter pago amanha', () {
    final vm = montar(aceita());

    expect(vm.ultimoDiaValido, DateTime(2026, 11, 13));
  });

  test('manda valor, data e forma para a rota do inquilino', () async {
    final api = aceita();
    final vm = montar(api);

    vm.escolherForma('transferencia');
    vm.escolherData(DateTime(2026, 11, 12));
    expect(await vm.salvar(), isTrue);

    expect(api.corpoDe('POST /minhas-cobrancas/7/aviso-pagamento'), {
      'valor': total,
      'data_pagamento': '2026-11-12',
      'forma': 'transferencia',
    });
  });

  test('o aviso nao muda o status: a cobranca volta em aberto', () async {
    final api = aceita();
    final vm = montar(api);

    await vm.salvar();

    // Deixar o inquilino quitar sozinho seria pior do que nao ter o
    // recurso: a cobranca apareceria paga sem ninguem ter conferido.
    expect(vm.enviado!.paga, isFalse);
    expect(vm.enviado!.foiAvisada, isTrue);
    expect(vm.confirmacao, contains('segue em aberto'));
    expect(vm.confirmacao, contains('confirmar o recebimento'));
  });

  test('corrigir confirma de outro jeito', () async {
    final vm = montar(aceita(), aviso: avisoJson(valor: 50000));

    await vm.salvar();

    expect(vm.confirmacao, 'Aviso corrigido. O proprietario vai conferir.');
  });

  test('cobranca ja paga volta 409 e a mensagem fica na folha', () async {
    final api = ApiFalsa({
      'POST /minhas-cobrancas/7/aviso-pagamento':
          const Falha(409, 'Esta cobranca ja consta como paga'),
    });
    final vm = montar(api);

    expect(await vm.salvar(), isFalse);
    expect(vm.erro, 'Esta cobranca ja consta como paga');
    expect(vm.salvando, isFalse);
  });

  test('so aceita as formas que a API conhece', () {
    final vm = montar(aceita());

    vm.escolherForma('boleto');
    expect(vm.forma, 'pix');
    vm.escolherForma('dinheiro');
    expect(vm.forma, 'dinheiro');
  });
}
