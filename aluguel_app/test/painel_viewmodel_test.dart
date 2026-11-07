import 'package:aluguel_app/core/state/competencia_store.dart';
import 'package:aluguel_app/data/models/unidade.dart';
import 'package:aluguel_app/data/repositories/auth_repository.dart';
import 'package:aluguel_app/data/repositories/cobranca_repository.dart';
import 'package:aluguel_app/data/repositories/competencia_repository.dart';
import 'package:aluguel_app/data/repositories/imovel_repository.dart';
import 'package:aluguel_app/features/unidades/viewmodel/painel_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/api_falsa.dart';

void main() {
  /// Um ponto com tres unidades: uma paga, uma em aberto e uma vaga.
  ApiFalsa cenario() => ApiFalsa({
        'GET /competencias': [
          competenciaJson('2026-11', atual: true),
          competenciaJson('2026-10', cobrancas: 2, imoveisFechados: 1),
        ],
        'GET /imoveis': [imovelJson(1, unidades: 3, unidadesOcupadas: 2)],
        'GET /unidades': [
          unidadeJson(1, cobrancaStatus: 'paga', cobrancaTotal: 100000),
          unidadeJson(2,
              identificacao: 'Kitnet 02',
              inquilino: 'Jose Andrade',
              cobrancaStatus: 'aberta',
              cobrancaTotal: 90000),
          unidadeJson(3,
              identificacao: 'Kitnet 03',
              status: 'vaga',
              inquilino: null,
              valorAluguel: null),
        ],
        'GET /cobrancas': [
          cobrancaJson(1,
              unidadeId: 1, aluguel: 65000, agua: 12000, energia: 23000,
              status: 'paga'),
          cobrancaJson(2,
              unidadeId: 2,
              contratoId: 2,
              identificacao: 'Kitnet 02',
              inquilino: 'Jose Andrade',
              aluguel: 62000,
              agua: 10000,
              energia: 18000,
              status: 'aberta'),
        ],
      });

  Future<(PainelViewModel, CompetenciaStore)> montar(ApiFalsa api) async {
    final competencia =
        CompetenciaStore(CompetenciaRepository(api.cliente));
    await competencia.carregar();

    final vm = PainelViewModel(
      ImovelRepository(api.cliente),
      CobrancaRepository(api.cliente),
      AuthRepository(api.cliente),
      competencia,
    );
    await vm.carregar();
    return (vm, competencia);
  }

  test('agrupa as unidades por ponto e soma o subtotal', () async {
    final (vm, _) = await montar(cenario());

    expect(vm.grupos, hasLength(1));
    expect(vm.grupos.single.unidades, hasLength(3));
    expect(vm.grupos.single.subtotal, 190000);
    expect(vm.totalFormatado, r'R$ 1.900,00');
  });

  test('separa o que esta em aberto do que ja foi recebido', () async {
    final (vm, _) = await montar(cenario());

    expect(vm.totalRecebido, 100000);
    expect(vm.totalEmAberto, 90000);
    expect(vm.resumoRecebimento, r'R$ 900,00 em aberto  ·  R$ 1.000,00 recebido');
  });

  test('so ha cobranca para abrir onde o mes foi fechado', () async {
    final (vm, _) = await montar(cenario());
    final unidades = vm.grupos.single.unidades;

    // A paga tambem abre: dela da para compartilhar a quebra, que e o
    // comprovante do inquilino.
    expect(vm.temCobranca(unidades[0]), isTrue, reason: 'paga, mas existe');
    expect(vm.temCobranca(unidades[1]), isTrue);
    expect(vm.temCobranca(unidades[2]), isFalse, reason: 'vaga, nem cobranca ha');

    expect(vm.cobrancaDa(unidades[0])!.paga, isTrue);
    expect(vm.cobrancaDa(unidades[1])!.paga, isFalse);
  });

  test('pede os dados da competencia escolhida, nao de uma constante',
      () async {
    final api = cenario();
    final (vm, competencia) = await montar(api);

    expect(api.chamada('GET /unidades').url.queryParameters['competencia'],
        '2026-11');

    competencia.selecionar('2026-10');
    await vm.carregar();

    expect(api.chamadas.where((c) => c.url.path.endsWith('/unidades')).last
        .url.queryParameters['competencia'], '2026-10');
    expect(vm.competenciaFormatada, 'Outubro de 2026');
  });

  test('a unidade vaga convida para o contrato', () async {
    final (vm, _) = await montar(cenario());
    final vaga = vm.grupos.single.unidades[2];

    expect(vm.legendaDaUnidade(vaga), contains('toque para alugar'));
    expect(vm.valorDaUnidade(vaga), isEmpty);
  });

  test('a cobranca em aberto mostra o vencimento na legenda', () async {
    final (vm, _) = await montar(cenario());
    final emAberto = vm.grupos.single.unidades[1];

    expect(vm.legendaDaUnidade(emAberto), contains('vence 10/11/2026'));
  });

  test('o cadastro recebe os pontos e os nomes ja usados', () async {
    final (vm, _) = await montar(cenario());

    expect(vm.imoveis.single.id, 1);
    expect(vm.identificacoesPorImovel[1],
        ['Kitnet 01', 'Kitnet 02', 'Kitnet 03']);
  });

  test('sair limpa o painel e o mes escolhido', () async {
    final (vm, competencia) = await montar(cenario());

    vm.sair();

    expect(vm.grupos, isEmpty);
    expect(vm.resumoRecebimento, isNull);
    expect(competencia.opcoes, isEmpty);
  });

  test('erro de rede vira mensagem, nao excecao', () async {
    final api = ApiFalsa({'GET /competencias': <Object>[]});
    final (vm, _) = await montar(api);

    expect(vm.erro, isNotNull);
    expect(vm.grupos, isEmpty);
  });

  test('mes sem fechamento nenhum nao mostra a linha de recebimento',
      () async {
    final api = ApiFalsa({
      'GET /competencias': [competenciaJson('2026-11', atual: true)],
      'GET /imoveis': [imovelJson(1)],
      'GET /unidades': [unidadeJson(1)],
      'GET /cobrancas': <Object>[],
    });
    final (vm, _) = await montar(api);

    expect(vm.resumoRecebimento, isNull);
    expect(vm.cobrancaDa(vm.grupos.single.unidades.single), isNull);
  });

  test('unidade ocupada sem fechamento mostra o aluguel e avisa', () async {
    final api = ApiFalsa({
      'GET /competencias': [competenciaJson('2026-11', atual: true)],
      'GET /imoveis': [imovelJson(1)],
      'GET /unidades': [unidadeJson(1)],
      'GET /cobrancas': <Object>[],
    });
    final (vm, _) = await montar(api);
    final Unidade unidade = vm.grupos.single.unidades.single;

    expect(vm.valorDaUnidade(unidade), r'R$ 650,00');
    expect(vm.legendaDaUnidade(unidade), contains('mes ainda nao fechado'));
  });
}
