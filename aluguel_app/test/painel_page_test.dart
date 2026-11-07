import 'package:aluguel_app/core/state/competencia_store.dart';
import 'package:aluguel_app/core/theme/app_theme.dart';
import 'package:aluguel_app/data/repositories/auth_repository.dart';
import 'package:aluguel_app/data/repositories/cadastro_repository.dart';
import 'package:aluguel_app/data/repositories/cobranca_repository.dart';
import 'package:aluguel_app/data/repositories/competencia_repository.dart';
import 'package:aluguel_app/data/repositories/imovel_repository.dart';
import 'package:aluguel_app/features/unidades/view/painel_page.dart';
import 'package:aluguel_app/features/unidades/viewmodel/painel_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/api_falsa.dart';

/// Testes de tela do painel.
///
/// Cobrem a fiacao que o teste de ViewModel nao alcanca: que o seletor
/// abre, que o card leva a acao certa conforme o estado da unidade, e que
/// a tela recarrega depois.
void main() {
  ApiFalsa cenario() => ApiFalsa({
        'GET /competencias': [
          competenciaJson('2026-11', atual: true),
          competenciaJson('2026-10', cobrancas: 2, imoveisFechados: 1),
        ],
        'GET /imoveis': [imovelJson(1, unidades: 2, unidadesOcupadas: 1)],
        'GET /unidades': [
          unidadeJson(1, cobrancaStatus: 'aberta', cobrancaTotal: 100534),
          unidadeJson(3,
              identificacao: 'Kitnet 03',
              status: 'vaga',
              inquilino: null,
              valorAluguel: null),
        ],
        'GET /cobrancas': [
          cobrancaJson(1, aluguel: 65000, agua: 12534, energia: 23000),
        ],
        'GET /inquilinos': [
          {'id': 1, 'nome': 'Pedro Lima', 'telefone': '', 'unidades': <String>[]},
        ],
      });

  Future<void> abrirPainel(WidgetTester tester, ApiFalsa api) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: api.cliente),
          Provider(create: (_) => AuthRepository(api.cliente)),
          Provider(create: (_) => ImovelRepository(api.cliente)),
          Provider(create: (_) => CobrancaRepository(api.cliente)),
          Provider(create: (_) => CadastroRepository(api.cliente)),
          Provider(create: (_) => CompetenciaRepository(api.cliente)),
          ChangeNotifierProvider(
            create: (ctx) =>
                CompetenciaStore(ctx.read<CompetenciaRepository>()),
          ),
          ChangeNotifierProvider(
            create: (ctx) => PainelViewModel(
              ctx.read<ImovelRepository>(),
              ctx.read<CobrancaRepository>(),
              ctx.read<AuthRepository>(),
              ctx.read<CompetenciaStore>(),
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const PainelPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('abre no mes mais recente, com o total e o que esta em aberto',
      (tester) async {
    await abrirPainel(tester, cenario());

    expect(find.text('Novembro de 2026'), findsOneWidget);
    expect(find.text(r'R$ 1.005,34'), findsWidgets);
    expect(
      find.text(r'R$ 1.005,34 em aberto  ·  R$ 0,00 recebido'),
      findsOneWidget,
    );
    expect(find.text('Kitnet 03'), findsOneWidget);
  });

  testWidgets('o seletor lista os meses e troca a competencia',
      (tester) async {
    final api = cenario();
    await abrirPainel(tester, api);

    await tester.tap(find.text('Novembro de 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Competencia'), findsOneWidget);
    expect(find.text('Outubro de 2026'), findsOneWidget);
    expect(find.text('1 de 2 pontos fechados'), findsOneWidget);

    await tester.tap(find.text('Outubro de 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Outubro de 2026'), findsOneWidget,
        reason: 'virou o titulo do cabecalho');
    expect(
      api.chamadas
          .where((c) => c.url.path.endsWith('/unidades'))
          .last
          .url
          .queryParameters['competencia'],
      '2026-10',
    );
  });

  testWidgets('o card com cobranca aberta abre a folha de pagamento',
      (tester) async {
    await abrirPainel(tester, cenario());

    await tester.tap(find.text('Kitnet 01'));
    await tester.pumpAndSettle();

    expect(find.text('Registrar pagamento'), findsWidgets);
    expect(find.text('Total da cobranca'), findsOneWidget);
    expect(find.text('Pix'), findsOneWidget);
    // O valor ja vem preenchido com o total da cobranca.
    expect(find.widgetWithText(TextField, '1.005,34'), findsOneWidget);
  });

  testWidgets('o card vago leva ao contrato, com a unidade no titulo',
      (tester) async {
    await abrirPainel(tester, cenario());

    await tester.tap(find.text('Kitnet 03'));
    await tester.pumpAndSettle();

    expect(find.text('Alugar Kitnet 03'), findsOneWidget);
    expect(find.text('Escolha quem vai morar'), findsOneWidget);

    // A lista de pessoas chegou: so aparece com o dropdown aberto.
    // O primeiro e o de inquilino; o segundo e o dia do vencimento.
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    expect(find.text('Pedro Lima'), findsWidgets);
  });

  testWidgets('o botao de nova unidade abre o cadastro', (tester) async {
    await abrirPainel(tester, cenario());

    await tester.tap(find.text('Nova unidade'));
    await tester.pumpAndSettle();

    expect(find.text('Identificacao'), findsOneWidget);
    expect(find.text('Ja tem 2 unidades: Kitnet 01, Kitnet 03'),
        findsOneWidget);
  });

  testWidgets('registrar o pagamento fecha a folha e recarrega o painel',
      (tester) async {
    final api = cenario();
    api.rotas['POST /cobrancas/1/pagamento'] = {
      'id': 1,
      'cobranca_id': 1,
      'valor': 100534,
      'data_pagamento': '2026-11-07',
      'forma': 'pix',
      'cobranca_status': 'paga',
    };
    // Depois do pagamento o servidor passa a responder que ela esta paga.
    await abrirPainel(tester, api);

    await tester.tap(find.text('Kitnet 01'));
    await tester.pumpAndSettle();

    api.rotas['GET /unidades'] = [
      unidadeJson(1, cobrancaStatus: 'paga', cobrancaTotal: 100534),
      unidadeJson(3,
          identificacao: 'Kitnet 03',
          status: 'vaga',
          inquilino: null,
          valorAluguel: null),
    ];
    api.rotas['GET /cobrancas'] = [
      cobrancaJson(1, aluguel: 65000, agua: 12534, energia: 23000,
          status: 'paga'),
    ];

    await tester.tap(find.widgetWithText(ElevatedButton, 'Registrar pagamento'));
    await tester.pumpAndSettle();

    expect(find.text('Total da cobranca'), findsNothing,
        reason: 'a folha fechou');
    expect(find.text('Kitnet 01: cobranca quitada'), findsOneWidget);
    expect(
      find.text(r'R$ 0,00 em aberto  ·  R$ 1.005,34 recebido'),
      findsOneWidget,
    );
  });

  testWidgets('a cobranca paga abre so para compartilhar', (tester) async {
    final api = cenario();
    api.rotas['GET /unidades'] = [
      unidadeJson(1, cobrancaStatus: 'paga', cobrancaTotal: 100534),
    ];
    api.rotas['GET /cobrancas'] = [
      cobrancaJson(1,
          aluguel: 65000, agua: 12534, energia: 23000, status: 'paga'),
    ];
    await abrirPainel(tester, api);

    await tester.tap(find.text('Kitnet 01'));
    await tester.pumpAndSettle();

    expect(find.text('Cobranca paga'), findsOneWidget);
    expect(find.text('Compartilhar com o inquilino'), findsOneWidget);
    // A rota de pagamento devolve 409 para cobranca paga: oferecer o
    // botao so serviria para dar erro.
    expect(find.text('Registrar pagamento'), findsNothing);
    expect(find.text('Forma'), findsNothing);
  });

  testWidgets('a cobranca em aberto abre com as duas acoes', (tester) async {
    await abrirPainel(tester, cenario());

    await tester.tap(find.text('Kitnet 01'));
    await tester.pumpAndSettle();

    expect(find.text('Cobranca em aberto'), findsOneWidget);
    expect(find.text('Compartilhar com o inquilino'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Registrar pagamento'),
        findsOneWidget);
  });

  testWidgets('erro de rede mostra a tela de tentar de novo', (tester) async {
    await abrirPainel(tester, ApiFalsa({}));

    expect(find.text('Nao deu para carregar'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.text('Nova unidade'), findsNothing,
        reason: 'sem ponto carregado nao ha onde pendurar uma unidade');
  });
}
