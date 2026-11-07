import 'package:aluguel_app/data/datasources/leituras_locais.dart';
import 'package:aluguel_app/data/repositories/leitura_repository.dart';
import 'package:aluguel_app/features/leituras/viewmodel/leituras_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/api_falsa.dart';

/// A Kitnet 01 gasta 160 kWh e 7 m3 por mes, ha dois meses.
ApiFalsa comHistorico() => ApiFalsa({
      'GET /leituras': [
        leituraJson(1,
            tipo: 'agua',
            valorAnterior: 142.5,
            mediaConsumo: 7.0,
            mesesHistorico: 2),
        leituraJson(1,
            tipo: 'energia',
            valorAnterior: 3180,
            mediaConsumo: 160.0,
            mesesHistorico: 2),
      ],
      'POST /leituras': <Object>[],
    });

/// Unidade recem-alugada: um mes de historico nao faz media.
ApiFalsa semHistorico() => ApiFalsa({
      'GET /leituras': [
        leituraJson(1,
            tipo: 'agua', valorAnterior: 142.5, mediaConsumo: 7.0,
            mesesHistorico: 1),
        leituraJson(1,
            tipo: 'energia', valorAnterior: 3180, mediaConsumo: 160.0,
            mesesHistorico: 1),
      ],
    });

Future<LeiturasViewModel> montar(ApiFalsa api, {LeiturasLocais? locais}) async {
  final vm = LeiturasViewModel(
    LeituraRepository(api.cliente, locais ?? LeiturasLocais()),
    imovelId: 1,
    competencia: '2026-11',
  );
  await vm.carregar();
  return vm;
}

/// Faz o que o `TextField` faz na tela: poe o texto no controller e
/// avisa a ViewModel. Chamar so `validar` nao preenche o campo, e o
/// salvamento le o campo.
void digitar(LeiturasViewModel vm, LinhaLeitura linha, String tipo,
    String texto) {
  if (tipo == 'agua') {
    linha.controllerAgua.text = texto;
  } else {
    linha.controllerEnergia.text = texto;
  }
  vm.validar(linha, tipo, texto);
}

void main() {
  // O cache usa SharedPreferences; cada teste comeca com ele vazio.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('consumo dentro do normal nao avisa nada', () async {
    final vm = await montar(comHistorico());
    final linha = vm.linhas.single;

    // 3180 -> 3340 e exatamente os 160 kWh de sempre.
    vm.validar(linha, 'energia', '3340');

    expect(linha.avisoEnergia, isNull);
    expect(linha.erroEnergia, isNull);
    expect(vm.avisoRodape, isNull);
  });

  test('variacao comum de mes nao avisa', () async {
    final vm = await montar(comHistorico());
    final linha = vm.linhas.single;

    vm.validar(linha, 'energia', '3420'); // 240 kWh, 1,5x a media
    expect(linha.avisoEnergia, isNull);

    vm.validar(linha, 'energia', '3280'); // 100 kWh, 0,6x a media
    expect(linha.avisoEnergia, isNull);
  });

  test('a tecla a mais e pega pela media, que a regra antiga deixava passar',
      () async {
    final vm = await montar(comHistorico());
    final linha = vm.linhas.single;

    // 1600 kWh no lugar de 160: maior que a leitura anterior, entao a
    // regra de "nao pode andar para tras" aceita sem reclamar.
    vm.validar(linha, 'energia', '4780');

    expect(linha.erroEnergia, isNull, reason: 'nao e invalido, e suspeito');
    expect(linha.avisoEnergia,
        '10,0x o normal desta unidade (160 kWh por mes). Confere?');
  });

  test('digito a menos cai no limite de baixo', () async {
    final vm = await montar(comHistorico());
    final linha = vm.linhas.single;

    vm.validar(linha, 'energia', '3196'); // 16 kWh, um decimo do normal

    expect(linha.avisoEnergia,
        'Bem abaixo do normal desta unidade (160 kWh por mes). Confere?');
  });

  test('o aviso fala na unidade certa de cada medidor', () async {
    final vm = await montar(comHistorico());
    final linha = vm.linhas.single;

    vm.validar(linha, 'agua', '175'); // 32,5 m3 contra 7 de media

    expect(linha.avisoAgua, contains('7,0 m³ por mes'));
  });

  test('aviso nao trava o salvamento', () async {
    final vm = await montar(comHistorico());
    final linha = vm.linhas.single;

    vm.validar(linha, 'energia', '4780');

    expect(vm.temErro, isFalse);
    expect(vm.podeSalvar, isTrue);
    expect(vm.rodapeEhErro, isFalse);
    expect(vm.avisoRodape, contains('Da para salvar assim mesmo'));
  });

  test('erro tem precedencia sobre aviso, no campo e no rodape', () async {
    final vm = await montar(comHistorico());
    final linha = vm.linhas.single;

    vm.validar(linha, 'energia', '3000'); // menor que a anterior

    expect(linha.erroEnergia, 'Menor que a anterior (3180)');
    expect(linha.avisoEnergia, isNull);
    expect(vm.rodapeEhErro, isTrue);
    expect(vm.avisoRodape, 'Corrija a leitura de Kitnet 01 para continuar');
    expect(vm.podeSalvar, isFalse);
  });

  test('sem dois meses de historico nao ha padrao, entao nao ha aviso',
      () async {
    final vm = await montar(semHistorico());
    final linha = vm.linhas.single;

    vm.validar(linha, 'energia', '4780'); // dez vezes a media

    expect(linha.avisoEnergia, isNull,
        reason: 'um mes so nao e media de nada');
  });

  test('o que ja estava lancado tambem e conferido ao abrir a tela',
      () async {
    final api = ApiFalsa({
      'GET /leituras': [
        leituraJson(1,
            tipo: 'agua',
            valorAnterior: 142.5,
            valorAtual: 149.5,
            mediaConsumo: 7.0,
            mesesHistorico: 2),
        leituraJson(1,
            tipo: 'energia',
            valorAnterior: 3180,
            valorAtual: 4780, // lancado errado numa sessao anterior
            mediaConsumo: 160.0,
            mesesHistorico: 2),
      ],
    });
    final vm = await montar(api);
    final linha = vm.linhas.single;

    expect(linha.avisoAgua, isNull);
    expect(linha.avisoEnergia, contains('10,0x o normal'));
  });

  test('o limite alto e folgado para o aviso nao virar ruido', () {
    expect(LeiturasViewModel.limiteAlto, 3.0);
    expect(LeiturasViewModel.limiteBaixo, closeTo(0.333, 0.001));
  });

  group('sem sinal', () {
    test('com rede, a tela nao mostra tarja nenhuma', () async {
      final vm = await montar(comHistorico());

      expect(vm.offline, isFalse);
      expect(vm.temPendencia, isFalse);
      expect(vm.avisoDeSincronia, isNull);
    });

    test('ja tendo aberto com rede, abre de novo offline pelo espelho',
        () async {
      final locais = LeiturasLocais();

      // Primeira visita, com sinal: guarda o espelho.
      await montar(comHistorico(), locais: locais);

      // Volta na garagem, sem sinal.
      final semSinal = ApiFalsa({'GET /leituras': const SemRede()});
      final vm = await montar(semSinal, locais: locais);

      expect(vm.erro, isNull);
      expect(vm.linhas, hasLength(1));
      expect(vm.linhas.single.identificacao, 'Kitnet 01');
      expect(vm.linhas.single.agua.valorAnterior, 142.5);
      expect(vm.offline, isTrue);
      expect(vm.avisoDeSincronia, contains('Sem conexao'));
    });

    test('offline e sem nada guardado, nao ha o que mostrar', () async {
      final vm = await montar(ApiFalsa({'GET /leituras': const SemRede()}));

      expect(vm.linhas, isEmpty);
      expect(vm.erro, isNotNull);
      expect(vm.offline, isTrue);
    });

    test('salvar sem sinal guarda no aparelho em vez de perder', () async {
      final locais = LeiturasLocais();
      final api = comHistorico();
      final vm = await montar(api, locais: locais);

      digitar(vm, vm.linhas.single, 'energia', '3340');
      api.rotas['POST /leituras'] = const SemRede();

      // Devolve true: o valor esta a salvo, so nao chegou. Para quem
      // digitou, sair da tela agora nao perde nada.
      expect(await vm.salvar(), isTrue);
      expect(vm.erro, isNull);
      expect(vm.sucesso, contains('Guardado no aparelho'));
      expect(vm.linhas.single.pendenteEnergia, isTrue);
      expect(vm.temPendencia, isTrue);

      expect(await locais.pendencias(1, '2026-11'), {'1:energia': 3340.0});
    });

    test('a pendencia volta preenchida e marcada quando a tela reabre',
        () async {
      final locais = LeiturasLocais();
      final api = comHistorico();
      final vm = await montar(api, locais: locais);

      digitar(vm, vm.linhas.single, 'energia', '3340');
      api.rotas['POST /leituras'] = const SemRede();
      await vm.salvar();

      // Reabre, ainda sem sinal.
      final reaberta = await montar(
        ApiFalsa({'GET /leituras': const SemRede()}),
        locais: locais,
      );

      expect(reaberta.linhas.single.controllerEnergia.text, '3340');
      expect(reaberta.linhas.single.pendenteEnergia, isTrue);
      expect(reaberta.avisoDeSincronia,
          '1 leitura guardada no aparelho. Toque em salvar quando tiver sinal.');
    });

    test('a tarja conta medidores, nao unidades', () async {
      final locais = LeiturasLocais();
      final api = comHistorico();
      final vm = await montar(api, locais: locais);

      digitar(vm, vm.linhas.single, 'agua', '149,5');
      digitar(vm, vm.linhas.single, 'energia', '3340');
      api.rotas['POST /leituras'] = const SemRede();
      await vm.salvar();

      expect(vm.avisoDeSincronia, startsWith('2 leituras guardadas'));
    });

    test('voltando o sinal, salvar limpa a pendencia', () async {
      final locais = LeiturasLocais();
      final api = comHistorico();
      final vm = await montar(api, locais: locais);

      digitar(vm, vm.linhas.single, 'energia', '3340');
      api.rotas['POST /leituras'] = const SemRede();
      await vm.salvar();
      expect(vm.temPendencia, isTrue);

      api.rotas['POST /leituras'] = <Object>[];
      expect(await vm.salvar(), isTrue);

      expect(vm.sucesso, 'Leituras salvas');
      expect(vm.temPendencia, isFalse);
      expect(vm.offline, isFalse);
      expect(await locais.pendencias(1, '2026-11'), isEmpty);
    });

    test('recusa do servidor nao vira pendencia', () async {
      final locais = LeiturasLocais();
      final api = comHistorico();
      final vm = await montar(api, locais: locais);

      digitar(vm, vm.linhas.single, 'energia', '3340');
      api.rotas['POST /leituras'] =
          const Falha(422, 'Kitnet 01: leitura de energia e menor que a anterior');

      // Repetir um 422 mais tarde daria 422 de novo: guardar na fila so
      // adiaria o problema e deixaria quem digitou achando que resolveu.
      expect(await vm.salvar(), isFalse);
      expect(vm.erro, contains('menor que a anterior'));
      expect(vm.temPendencia, isFalse);
      expect(await locais.pendencias(1, '2026-11'), isEmpty);
    });

    test('erro de autenticacao sobe, nao cai no cache', () async {
      final locais = LeiturasLocais();
      await montar(comHistorico(), locais: locais);

      final vm = await montar(
        ApiFalsa({'GET /leituras': const Falha(401, 'Sessao expirada')}),
        locais: locais,
      );

      expect(vm.erro, 'Sessao expirada');
      expect(vm.offline, isFalse, reason: 'o servidor respondeu, e recusou');
      expect(vm.linhas, isEmpty);
    });
  });
}
