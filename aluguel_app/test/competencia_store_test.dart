import 'package:aluguel_app/core/state/competencia_store.dart';
import 'package:aluguel_app/data/repositories/competencia_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/api_falsa.dart';

void main() {
  CompetenciaStore store(ApiFalsa api) =>
      CompetenciaStore(CompetenciaRepository(api.cliente));

  ApiFalsa comMeses() => ApiFalsa({
        'GET /competencias': [
          competenciaJson('2026-11', atual: true),
          competenciaJson('2026-10', cobrancas: 3, imoveisFechados: 1),
          competenciaJson('2026-09', cobrancas: 3, imoveisFechados: 2),
        ],
      });

  test('abre no mes mais recente que a API conhece', () async {
    final loja = store(comMeses());
    await loja.carregar();

    expect(loja.atual, '2026-11');
    expect(loja.opcoes, hasLength(3));
    expect(loja.formatada, 'Novembro de 2026');
  });

  test('mantem a escolha de quem esta usando quando ela segue na lista',
      () async {
    final loja = store(comMeses());
    await loja.carregar();

    loja.selecionar('2026-09');
    await loja.carregar();

    expect(loja.atual, '2026-09');
  });

  test('selecionar devolve false para o mes que ja estava escolhido',
      () async {
    final loja = store(comMeses());
    await loja.carregar();

    expect(loja.selecionar('2026-10'), isTrue);
    expect(loja.selecionar('2026-10'), isFalse);
  });

  test('sem a lista, cai no mes do relogio do aparelho', () {
    final loja = store(comMeses());

    final agora = DateTime.now();
    expect(loja.atual, CompetenciaStore.doMes(agora));
    expect(loja.selecionada, isNull);
  });

  test('erro da API vira mensagem e lista vazia', () async {
    final api = ApiFalsa({'GET /competencias': const Falha(401, 'Token invalido')});
    final loja = store(api);

    await loja.carregar();

    expect(loja.erro, 'Token invalido');
    expect(loja.opcoes, isEmpty);
  });

  test('limpar nao notifica: quem ouve recarregaria sem token', () async {
    final loja = store(comMeses());
    await loja.carregar();

    var avisos = 0;
    loja.addListener(() => avisos++);
    loja.limpar();

    expect(avisos, 0);
    expect(loja.opcoes, isEmpty);
  });

  group('descricao do mes no seletor', () {
    test('mes fechado por inteiro conta as cobrancas', () async {
      final loja = store(comMeses());
      await loja.carregar();

      final setembro = loja.opcoes.last;
      expect(loja.rotulo(setembro), 'Setembro de 2026');
      expect(loja.descricao(setembro), contains('Fechado'));
      expect(loja.descricao(setembro), contains('3 cobrancas'));
    });

    test('mes fechado so em parte diz quantos pontos faltam', () async {
      final loja = store(comMeses());
      await loja.carregar();

      final outubro = loja.opcoes[1];
      expect(loja.descricao(outubro), '1 de 2 pontos fechados');
    });

    test('mes corrente com lancamento, mas sem fechamento', () async {
      final loja = store(comMeses());
      await loja.carregar();

      expect(
        loja.descricao(loja.opcoes.first),
        'Nenhum ponto fechado  ·  mes corrente',
      );
    });

    test('mes que acabou de virar diz que nao ha lancamento', () async {
      final loja = store(ApiFalsa({
        'GET /competencias': [
          competenciaJson('2026-12', atual: true, temLancamento: false),
          competenciaJson('2026-11', cobrancas: 3, imoveisFechados: 2),
        ],
      }));
      await loja.carregar();

      // "Nenhum ponto fechado" seria verdade, mas sugere que falta
      // fechar — quando na verdade ainda nao ha o que fechar.
      expect(loja.descricao(loja.opcoes.first),
          'Sem lancamento ainda  ·  mes corrente');
    });
  });

  group('em que mes o app abre', () {
    test('no mes novo, abre no anterior, que e o que esta sendo cobrado',
        () async {
      // Dia 1 de dezembro: dezembro entra na lista porque e o mes do
      // calendario, mas esta vazio. Abrir nele deixaria o painel zerado
      // enquanto quem usa ainda esta cobrando novembro, que vence dia 10.
      final loja = store(ApiFalsa({
        'GET /competencias': [
          competenciaJson('2026-12', atual: true, temLancamento: false),
          competenciaJson('2026-11', cobrancas: 3, imoveisFechados: 2),
          competenciaJson('2026-10', cobrancas: 3, imoveisFechados: 2),
        ],
      }));
      await loja.carregar();

      expect(loja.atual, '2026-11');
      expect(loja.formatada, 'Novembro de 2026');
    });

    test('o mes novo continua no seletor, a um toque', () async {
      final loja = store(ApiFalsa({
        'GET /competencias': [
          competenciaJson('2026-12', atual: true, temLancamento: false),
          competenciaJson('2026-11', cobrancas: 3, imoveisFechados: 2),
        ],
      }));
      await loja.carregar();

      expect(loja.opcoes.first.valor, '2026-12');
      expect(loja.selecionar('2026-12'), isTrue);
      expect(loja.atual, '2026-12');
    });

    test('com lancamento no mes corrente, abre nele mesmo', () async {
      final loja = store(comMeses());
      await loja.carregar();

      expect(loja.atual, '2026-11');
    });

    test('sistema recem-instalado abre no unico mes que existe', () async {
      final loja = store(ApiFalsa({
        'GET /competencias': [
          competenciaJson('2026-12', atual: true, temLancamento: false),
        ],
      }));
      await loja.carregar();

      expect(loja.atual, '2026-12');
    });
  });
}
