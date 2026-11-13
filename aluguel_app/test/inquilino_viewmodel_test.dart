import 'package:aluguel_app/core/utils/texto_cobranca.dart';
import 'package:aluguel_app/data/models/cobranca.dart';
import 'package:aluguel_app/data/repositories/auth_repository.dart';
import 'package:aluguel_app/data/repositories/inquilino_repository.dart';
import 'package:aluguel_app/features/inquilino/viewmodel/inquilino_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/api_falsa.dart';

/// A cobranca de novembro da Maria, com a quebra que a API passou a
/// guardar: 7,5 m3 medidos mais 1/3 de 1 m3 de area comum, a R$ 16,00.
Map<String, Object?> comQuebra({
  String competencia = '2026-11',
  String status = 'aberta',
}) =>
    cobrancaJson(
      1,
      aluguel: 65000,
      agua: 12533,
      energia: 23580,
      competencia: competencia,
      status: status,
      detalheAgua: detalheJson(
          consumo: 7.5, rateioComum: 0.333, valorUnitario: 1600.0),
      detalheEnergia: detalheJson(
          consumo: 165.0, rateioComum: 25.0, valorUnitario: 124.1071),
    );

ApiFalsa cenario({List<Object>? cobrancas}) => ApiFalsa({
      'GET /minhas-cobrancas': cobrancas ?? [comQuebra()],
      'GET /meu-consumo': [
        {
          'unidade_id': 1,
          'identificacao': 'Kitnet 01',
          'historico': [
            {'competencia': '2026-10', 'agua': 7.0, 'energia': 165.0},
            {'competencia': '2026-11', 'agua': 7.5, 'energia': null},
          ],
        },
      ],
    });

Future<InquilinoViewModel> montar(ApiFalsa api) async {
  final vm = InquilinoViewModel(
    InquilinoRepository(api.cliente),
    AuthRepository(api.cliente),
  );
  await vm.carregar();
  return vm;
}

void main() {
  group('de onde vem a conta', () {
    test('a agua diz o que foi medido, o comum e o preco do mes', () async {
      final vm = await montar(cenario());
      final cobranca = vm.cobrancas.single;

      expect(vm.aguaDe(cobranca), r'R$ 125,33');
      expect(vm.origemDe(cobranca, 'agua'),
          r'7,5 m³ seus e 0,3 m³ de area comum, a R$ 16,00/m³');
    });

    test('a energia usa kWh e inteiro', () async {
      final vm = await montar(cenario());

      expect(vm.origemDe(vm.cobrancas.single, 'energia'),
          r'165 kWh seus e 25 kWh de area comum, a R$ 1,24/kWh');
    });

    test('os tres numeros multiplicam de volta no que foi cobrado', () async {
      final vm = await montar(cenario());
      final detalhe = vm.cobrancas.single.detalheAgua!;

      // E a promessa que a linha faz: se nao fechasse, a tela estaria
      // mentindo com precisao.
      final exato = detalhe.consumoCobrado * detalhe.valorUnitario;
      expect(exato, closeTo(12533, 1.5));
    });

    test('cobranca sem quebra guardada nao inventa origem', () async {
      final vm = await montar(cenario(cobrancas: [cobrancaJson(1)]));
      final cobranca = vm.cobrancas.single;

      expect(cobranca.temDetalhe, isFalse);
      expect(vm.origemDe(cobranca, 'agua'), isNull);
      expect(vm.explicacaoDoRateio, isNull,
          reason: 'sem quebra em lugar nenhum, nao ha o que explicar');
    });

    test('a explicacao do rateio aparece uma vez, quando ha quebra',
        () async {
      final vm = await montar(cenario());

      expect(vm.explicacaoDoRateio, contains('dividida igualmente'));
    });
  });

  group('o que o inquilino ve no topo', () {
    test('cobranca em aberto soma e conta', () async {
      final vm = await montar(cenario());

      expect(vm.temPendencia, isTrue);
      expect(vm.totalFormatado, r'R$ 1.011,13');
      expect(vm.resumoCabecalho, '1 cobranca em aberto');
    });

    test('atraso aparece no resumo', () async {
      final vm = await montar(cenario(cobrancas: [
        comQuebra(competencia: '2026-10', status: 'atrasada'),
        comQuebra(),
      ]));

      expect(vm.resumoCabecalho, '2 cobrancas em aberto  ·  1 em atraso');
    });

    test('tudo pago zera o topo', () async {
      final vm = await montar(cenario(cobrancas: [comQuebra(status: 'paga')]));

      expect(vm.temPendencia, isFalse);
      expect(vm.resumoCabecalho, 'Tudo pago  ·  nada em aberto');
      expect(vm.valorCabecalho, r'R$ 0,00');
    });

    test('mais recente primeiro: e a que o inquilino abriu o app para ver',
        () async {
      final vm = await montar(cenario(cobrancas: [
        comQuebra(competencia: '2026-09', status: 'paga'),
        comQuebra(competencia: '2026-11'),
        comQuebra(competencia: '2026-10', status: 'paga'),
      ]));

      expect([for (final c in vm.cobrancas) c.competencia],
          ['2026-11', '2026-10', '2026-09']);
    });

    test('consumo nao lancado vira travessao, que nao e zero', () async {
      final vm = await montar(cenario());
      final novembro = vm.consumo.single.historico.last;

      expect(vm.aguaConsumidaDe(novembro), '7,5 m³');
      expect(vm.energiaConsumidaDe(novembro), '—');
    });
  });

  group('avisar que pagou', () {
    test('da para avisar enquanto nao esta paga', () async {
      final vm = await montar(cenario(cobrancas: [
        comQuebra(),
        comQuebra(competencia: '2026-10', status: 'paga'),
      ]));

      expect(vm.podeAvisar(vm.cobrancas.first), isTrue);
      expect(vm.rotuloDoAviso(vm.cobrancas.first), 'Avisar que paguei');
      expect(vm.podeAvisar(vm.cobrancas.last), isFalse,
          reason: 'paga nao tem o que avisar');
    });

    test('avisada, o botao vira correcao e o card diz o que foi informado',
        () async {
      final avisada = {
        ...comQuebra(),
        'pagamento_informado':
            avisoJson(valor: 100000, dataPagamento: '2026-11-12'),
      };
      final vm = await montar(cenario(cobrancas: [avisada]));
      final cobranca = vm.cobrancas.single;

      expect(cobranca.foiAvisada, isTrue);
      expect(cobranca.paga, isFalse, reason: 'o aviso nao quita nada');
      expect(vm.rotuloDoAviso(cobranca), 'Corrigir o aviso');
      expect(vm.avisoEnviadoDe(cobranca),
          r'Voce informou R$ 1.000,00 em 12/11/2026. '
          'Aguardando a confirmacao do proprietario.');
    });

    test('sem aviso, o card nao mostra linha de espera', () async {
      final vm = await montar(cenario());

      expect(vm.avisoEnviadoDe(vm.cobrancas.single), isNull);
    });
  });

  group('comprovante', () {
    test('o inquilino manda o mesmo texto que o dono manda', () async {
      final vm = await montar(cenario());
      final cobranca = vm.cobrancas.single;

      expect(TextoCobranca.corpo(cobranca), '''
Kitnet 01 — Novembro de 2026

Aluguel: R\$ 650,00
Água: R\$ 125,33
  7,5 m³ seus e 0,3 m³ de área comum, a R\$ 16,00/m³
Energia: R\$ 235,80
  165 kWh seus e 25 kWh de área comum, a R\$ 1,24/kWh
Total: R\$ 1.011,13

Vence em 10/11/2026

Água e energia incluem a parte da área comum do ponto, dividida igualmente entre as unidades ocupadas.''');
    });

    test('sem quebra, o texto sai sem as linhas de origem', () async {
      final cobranca = Cobranca.fromJson(cobrancaJson(1));

      expect(TextoCobranca.corpo(cobranca), isNot(contains('seus e')));
      expect(TextoCobranca.corpo(cobranca), contains('Água: '));
    });

    test('o comprovante de cobranca paga diz pago, nao vencimento',
        () async {
      final vm = await montar(cenario(cobrancas: [comQuebra(status: 'paga')]));

      final texto = TextoCobranca.corpo(vm.cobrancas.single);
      expect(texto, contains('Situação: pago'));
      expect(texto, isNot(contains('Vence em')));
    });
  });
}
