import 'package:aluguel_app/data/repositories/leitura_repository.dart';
import 'package:aluguel_app/features/leituras/viewmodel/leituras_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

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

Future<LeiturasViewModel> montar(ApiFalsa api) async {
  final vm = LeiturasViewModel(
    LeituraRepository(api.cliente),
    imovelId: 1,
    competencia: '2026-11',
  );
  await vm.carregar();
  return vm;
}

void main() {
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
}
