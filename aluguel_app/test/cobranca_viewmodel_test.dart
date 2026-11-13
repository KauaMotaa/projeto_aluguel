import 'package:aluguel_app/data/models/cobranca.dart';
import 'package:aluguel_app/data/repositories/cobranca_repository.dart';
import 'package:aluguel_app/features/cobrancas/viewmodel/cobranca_viewmodel.dart';
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

  CobrancaViewModel montar(ApiFalsa api) => CobrancaViewModel(
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

  group('texto para compartilhar', () {
    test('traz a quebra inteira, o vencimento e a explicacao do rateio', () {
      final vm = montar(aceita());

      expect(vm.textoParaCompartilhar, '''
Kitnet 01 — Novembro de 2026

Aluguel: R\$ 650,00
Água: R\$ 125,34
Energia: R\$ 235,81
Total: R\$ 1.011,15

Vence em 10/11/2026

Água e energia incluem a parte da área comum do ponto, dividida igualmente entre as unidades ocupadas.''');
    });

    test('vai acentuado, porque sai do app e chega numa pessoa', () {
      final vm = montar(aceita());

      expect(vm.textoParaCompartilhar, contains('Água'));
      expect(vm.textoParaCompartilhar, contains('área comum'));
      expect(vm.assuntoParaCompartilhar,
          'Cobrança de Kitnet 01 — Novembro de 2026');
    });

    test('explica o rateio, que e o que evita a discussao de todo mes', () {
      // Sem essa linha o inquilino soma a propria leitura, acha menos do
      // que esta cobrado, e a conversa comeca errada.
      expect(montar(aceita()).textoParaCompartilhar,
          contains('dividida igualmente entre as unidades ocupadas'));
    });

    test('cobranca paga troca o vencimento pela situacao', () {
      final paga = Cobranca.fromJson(cobrancaJson(
        7,
        aluguel: 65000,
        agua: 12534,
        energia: 23581,
        status: 'paga',
      ));
      final vm = CobrancaViewModel(
        CobrancaRepository(aceita().cliente),
        cobranca: paga,
        hoje: DateTime(2026, 11, 7),
      );

      expect(vm.quitada, isTrue);
      expect(vm.textoParaCompartilhar, contains('Situação: pago'));
      expect(vm.textoParaCompartilhar, isNot(contains('Vence em')));
    });

    test('marco sai com cedilha', () {
      final marco = Cobranca.fromJson(cobrancaJson(
        7,
        competencia: '2026-03',
        vencimento: '2026-03-10',
      ));
      final vm = CobrancaViewModel(
        CobrancaRepository(aceita().cliente),
        cobranca: marco,
        hoje: DateTime(2026, 3, 7),
      );

      expect(vm.textoParaCompartilhar, contains('Março de 2026'));
    });
  });

  group('aviso do inquilino', () {
    CobrancaViewModel comAviso(Map<String, Object?> aviso) => CobrancaViewModel(
          CobrancaRepository(aceita().cliente),
          cobranca: Cobranca.fromJson(cobrancaJson(
            7,
            aluguel: 65000,
            agua: 12534,
            energia: 23581,
            pagamentoInformado: aviso,
          )),
          hoje: DateTime(2026, 11, 13),
        );

    test('sem aviso, nada aparece e o valor e o total', () {
      final vm = montar(aceita());

      expect(vm.avisoDoInquilino, isNull);
      expect(vm.centavos, total);
    });

    test('o dono le o que o inquilino informou', () {
      final vm = comAviso(avisoJson(
          valor: 100000, dataPagamento: '2026-11-12', forma: 'transferencia'));

      expect(vm.avisoDoInquilino,
          r'Maria Souza informou R$ 1.000,00 por Transferencia em 12/11/2026.');
    });

    test('o formulario abre com o que ele disse, nao com o total', () {
      // Conferir um numero ja preenchido e mais rapido, e menos sujeito a
      // engano, do que digitar de novo o que o outro lado ja informou.
      final vm = comAviso(avisoJson(valor: 100000, forma: 'dinheiro'));

      expect(vm.centavos, 100000);
      expect(vm.forma, 'dinheiro');
      expect(vm.avisoValor, contains('Pagamento parcial'),
          reason: 'informou menos que o total, e isso continua valendo');
    });
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
