import 'package:aluguel_app/data/models/imovel.dart';
import 'package:aluguel_app/data/models/unidade.dart';
import 'package:aluguel_app/data/repositories/cadastro_repository.dart';
import 'package:aluguel_app/features/cadastro/viewmodel/contrato_form_viewmodel.dart';
import 'package:aluguel_app/features/cadastro/viewmodel/unidade_form_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/api_falsa.dart';

void main() {
  group('nova unidade', () {
    final imoveis = [
      Imovel.fromJson(imovelJson(1)),
      Imovel.fromJson(imovelJson(2,
          nome: '104 Sul', endereco: 'Quadra 104 Sul, Alameda 12')),
    ];

    const existentes = {
      1: ['Kitnet 01', 'Kitnet 02'],
      2: <String>[],
    };

    UnidadeFormViewModel montar(ApiFalsa api) => UnidadeFormViewModel(
          CadastroRepository(api.cliente),
          imoveis: imoveis,
          existentes: existentes,
        );

    ApiFalsa aceita() => ApiFalsa({
          'POST /unidades': unidadeJson(7,
              identificacao: 'Kitnet 05',
              status: 'vaga',
              inquilino: null,
              valorAluguel: null),
        });

    test('abre no primeiro ponto e conta o que ele ja tem', () {
      final vm = montar(aceita());

      expect(vm.imovelId, 1);
      expect(vm.resumoDoImovel, 'Ja tem 2 unidades: Kitnet 01, Kitnet 02');
      expect(vm.podeSalvar, isFalse, reason: 'falta a identificacao');
    });

    test('recusa nome que ja existe no ponto, sem olhar maiuscula', () {
      final vm = montar(aceita());

      vm.controllerIdentificacao.text = 'kitnet 02';
      vm.validar();

      expect(vm.erroIdentificacao,
          'Este ponto ja tem uma unidade com esse nome');
      expect(vm.podeSalvar, isFalse);
    });

    test('o mesmo nome passa noutro ponto', () {
      final vm = montar(aceita());

      vm.controllerIdentificacao.text = 'Kitnet 02';
      vm.validar();
      expect(vm.erroIdentificacao, isNotNull);

      vm.escolherImovel(2);

      expect(vm.erroIdentificacao, isNull);
      expect(vm.resumoDoImovel, 'Nenhuma unidade cadastrada neste ponto');
      expect(vm.podeSalvar, isTrue);
    });

    test('manda o ponto escolhido e confirma que nasceu vaga', () async {
      final api = aceita();
      final vm = montar(api);

      vm.escolherImovel(2);
      vm.controllerIdentificacao.text = '  Kitnet 05  ';
      expect(await vm.salvar(), isTrue);

      expect(api.corpoDe('POST /unidades'),
          {'imovel_id': 2, 'identificacao': 'Kitnet 05'});
      expect(vm.confirmacao, 'Kitnet 05 cadastrada, ainda sem inquilino');
    });

    test('erro da API fica na tela', () async {
      final api = ApiFalsa({
        'POST /unidades': const Falha(404, 'Imovel nao encontrado'),
      });
      final vm = montar(api);

      vm.controllerIdentificacao.text = 'Kitnet 09';
      expect(await vm.salvar(), isFalse);
      expect(vm.erro, 'Imovel nao encontrado');
    });
  });

  group('contrato', () {
    final vaga = Unidade.fromJson(unidadeJson(3,
        identificacao: 'Kitnet 03',
        status: 'vaga',
        inquilino: null,
        valorAluguel: null));

    ContratoFormViewModel montar(ApiFalsa api) => ContratoFormViewModel(
          CadastroRepository(api.cliente),
          unidade: vaga,
          hoje: DateTime(2026, 11, 7),
        );

    Map<String, Object?> inquilinoJson(int id, String nome,
            {List<String> unidades = const []}) =>
        {'id': id, 'nome': nome, 'telefone': '', 'unidades': unidades};

    Map<String, Object?> contratoJson({
      int inquilinoId = 1,
      String inquilino = 'Maria Souza',
      int valor = 60000,
    }) =>
        {
          'id': 6,
          'unidade_id': 3,
          'inquilino_id': inquilinoId,
          'inquilino': inquilino,
          'valor_aluguel': valor,
          'dia_vencimento': 10,
          'data_inicio': '2026-11-07',
          'ativo': true,
        };

    ApiFalsa comPessoas() => ApiFalsa({
          'GET /inquilinos': [
            inquilinoJson(1, 'Maria Souza', unidades: ['Kitnet 01']),
            inquilinoJson(2, 'Pedro Lima'),
          ],
          'POST /contratos': contratoJson(inquilinoId: 2, inquilino: 'Pedro Lima'),
        });

    test('o titulo diz qual unidade esta sendo alugada', () {
      expect(montar(comPessoas()).titulo, 'Alugar Kitnet 03');
    });

    test('lista as pessoas e avisa quem ja esta alojado', () async {
      final vm = montar(comPessoas());
      await vm.carregar();

      expect(vm.inquilinos, hasLength(2));
      expect(vm.novoInquilino, isFalse);

      vm.escolherInquilino(1);
      expect(vm.avisoInquilino, 'Maria Souza ja ocupa Kitnet 01');

      vm.escolherInquilino(2);
      expect(vm.avisoInquilino, isNull, reason: 'Pedro nao mora em lugar nenhum');
    });

    test('sem ninguem cadastrado, abre direto no nome novo', () async {
      final vm = montar(ApiFalsa({'GET /inquilinos': <Object>[]}));
      await vm.carregar();

      expect(vm.novoInquilino, isTrue);
    });

    test('nao salva sem valor de aluguel', () async {
      final vm = montar(comPessoas());
      await vm.carregar();
      vm.escolherInquilino(2);

      expect(vm.podeSalvar, isFalse);

      vm.controllerValor.text = '600,00';
      vm.validar();
      expect(vm.podeSalvar, isTrue);
    });

    test('nao salva sem escolher quem vai morar', () async {
      final vm = montar(comPessoas());
      await vm.carregar();

      vm.controllerValor.text = '600,00';
      vm.validar();

      expect(vm.podeSalvar, isFalse);
    });

    test('pessoa ja cadastrada: uma chamada so', () async {
      final api = comPessoas();
      final vm = montar(api);
      await vm.carregar();

      vm.escolherInquilino(2);
      vm.controllerValor.text = '600,00';
      vm.escolherDia(5);
      vm.escolherDataInicio(DateTime(2026, 12, 1));

      expect(await vm.salvar(), isTrue);
      expect(api.chamou('POST /inquilinos'), isFalse);
      expect(api.corpoDe('POST /contratos'), {
        'unidade_id': 3,
        'inquilino_id': 2,
        'valor_aluguel': 60000,
        'dia_vencimento': 5,
        'data_inicio': '2026-12-01',
      });
    });

    test('nome novo: cria a pessoa antes do contrato', () async {
      final api = ApiFalsa({
        'GET /inquilinos': <Object>[],
        'POST /inquilinos': inquilinoJson(9, 'Ana Nova'),
        'POST /contratos': contratoJson(inquilinoId: 9, inquilino: 'Ana Nova'),
      });
      final vm = montar(api);
      await vm.carregar();

      vm.controllerNome.text = 'Ana Nova';
      vm.controllerTelefone.text = '63 99000-0010';
      vm.controllerValor.text = '600,00';
      vm.validar();

      expect(await vm.salvar(), isTrue);
      expect(api.ordem, [
        'GET /inquilinos',
        'POST /inquilinos',
        'POST /contratos',
      ]);
      expect(api.corpoDe('POST /contratos')['inquilino_id'], 9);
      expect(vm.confirmacao, r'Kitnet 03 alugada para Ana Nova por R$ 600,00');
    });

    test('nome curto demais barra o botao', () async {
      final vm = montar(ApiFalsa({'GET /inquilinos': <Object>[]}));
      await vm.carregar();

      vm.controllerNome.text = 'A';
      vm.controllerValor.text = '600,00';
      vm.validar();

      expect(vm.erroNome, 'Nome muito curto');
      expect(vm.podeSalvar, isFalse);
    });

    test('contrato duplicado volta como erro da API', () async {
      final api = ApiFalsa({
        'GET /inquilinos': [inquilinoJson(2, 'Pedro Lima')],
        'POST /contratos':
            const Falha(409, 'A unidade ja tem contrato ativo'),
      });
      final vm = montar(api);
      await vm.carregar();

      vm.escolherInquilino(2);
      vm.controllerValor.text = '600,00';

      expect(await vm.salvar(), isFalse);
      expect(vm.erro, 'A unidade ja tem contrato ativo');
    });

    test('o resumo diz quando a cobranca vai cair', () async {
      final vm = montar(comPessoas());
      await vm.carregar();

      expect(vm.resumoVencimento, 'Todo dia 10, a partir de 07/11/2026');

      vm.escolherDia(5);
      expect(vm.resumoVencimento, 'Todo dia 5, a partir de 07/11/2026');
    });

    test('o vencimento para no dia 28, porque fevereiro existe', () {
      expect(ContratoFormViewModel.diasVencimento.last, 28);
    });
  });
}
