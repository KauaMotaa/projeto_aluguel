import 'package:aluguel_app/core/theme/app_theme.dart';
import 'package:aluguel_app/core/widgets/barras_consumo.dart';
import 'package:aluguel_app/data/repositories/auth_repository.dart';
import 'package:aluguel_app/data/repositories/inquilino_repository.dart';
import 'package:aluguel_app/features/inquilino/view/inquilino_page.dart';
import 'package:aluguel_app/features/inquilino/viewmodel/inquilino_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/api_falsa.dart';

/// Testes de tela do inquilino.
///
/// Cobrem a fiacao que o teste de ViewModel nao alcanca: que a origem da
/// conta chega na tela, que o botao de avisar aparece so onde cabe, e que
/// o historico virou grafico.
void main() {
  Map<String, Object?> cobranca({
    String competencia = '2026-11',
    String status = 'aberta',
    Map<String, Object?>? aviso,
  }) =>
      cobrancaJson(
        1,
        aluguel: 65000,
        agua: 12533,
        energia: 23580,
        competencia: competencia,
        status: status,
        pagamentoInformado: aviso,
        detalheAgua: detalheJson(
            consumo: 7.5, rateioComum: 0.333, valorUnitario: 1600.0),
        detalheEnergia: detalheJson(
            consumo: 165.0, rateioComum: 25.0, valorUnitario: 124.1071),
      );

  ApiFalsa cenario({List<Object>? cobrancas}) => ApiFalsa({
        'GET /minhas-cobrancas': cobrancas ?? [cobranca()],
        'GET /meu-consumo': [
          {
            'unidade_id': 1,
            'identificacao': 'Kitnet 01',
            'historico': [
              {'competencia': '2026-10', 'agua': 7.0, 'energia': 160.0},
              {'competencia': '2026-11', 'agua': 7.5, 'energia': 190.0},
            ],
          },
        ],
        'POST /minhas-cobrancas/1/aviso-pagamento':
            cobranca(aviso: avisoJson(valor: 101113)),
      });

  Future<void> abrir(WidgetTester tester, ApiFalsa api) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: api.cliente),
          Provider(create: (_) => InquilinoRepository(api.cliente)),
          Provider(create: (_) => AuthRepository(api.cliente)),
          ChangeNotifierProvider(
            create: (ctx) => InquilinoViewModel(
              ctx.read<InquilinoRepository>(),
              ctx.read<AuthRepository>(),
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const InquilinoPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a conta chega explicada, nao so somada', (tester) async {
    await abrir(tester, cenario());

    expect(find.text(r'R$ 125,33'), findsOneWidget);
    expect(find.text(r'7,5 m³ seus e 0,3 m³ de area comum, a R$ 16,00/m³'),
        findsOneWidget);
    expect(find.textContaining('dividida igualmente'), findsOneWidget);
  });

  testWidgets('o historico virou grafico, um por medidor', (tester) async {
    await abrir(tester, cenario());

    expect(find.byType(BarrasConsumo), findsNWidgets(2));
    expect(find.textContaining('7% acima do mes anterior'), findsOneWidget,
        reason: 'agua foi de 7,0 para 7,5');
    expect(find.textContaining('19% acima'), findsOneWidget,
        reason: 'energia foi de 160 para 190');
  });

  testWidgets('cobranca em aberto convida a avisar', (tester) async {
    await abrir(tester, cenario());

    expect(find.text('Avisar que paguei'), findsOneWidget);
  });

  testWidgets('cobranca paga nao tem o que avisar', (tester) async {
    await abrir(tester, cenario(cobrancas: [cobranca(status: 'paga')]));

    expect(find.text('Avisar que paguei'), findsNothing);
    expect(find.text('Corrigir o aviso'), findsNothing);
  });

  testWidgets('ja avisada, o card mostra a espera e oferece correcao',
      (tester) async {
    await abrir(
      tester,
      cenario(cobrancas: [
        cobranca(aviso: avisoJson(valor: 101113, dataPagamento: '2026-11-12')),
      ]),
    );

    expect(find.textContaining('Aguardando a confirmacao'), findsOneWidget);
    expect(find.text('Corrigir o aviso'), findsWidgets);
  });

  testWidgets('o aviso abre explicando que nada fica pago na hora',
      (tester) async {
    await abrir(tester, cenario());

    await tester.tap(find.text('Avisar que paguei'));
    await tester.pumpAndSettle();

    expect(find.textContaining('so fica paga quando'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Avisar o proprietario'),
        findsOneWidget);
    // O valor ja vem preenchido com o total da cobranca.
    expect(find.widgetWithText(TextField, '1.011,13'), findsOneWidget);
  });

  testWidgets('enviado o aviso, a tela recarrega e mostra a espera',
      (tester) async {
    final api = cenario();
    await abrir(tester, api);

    await tester.tap(find.text('Avisar que paguei'));
    await tester.pumpAndSettle();

    // O servidor passa a devolver a cobranca com o recado anexado.
    api.rotas['GET /minhas-cobrancas'] = [
      cobranca(aviso: avisoJson(valor: 101113)),
    ];

    await tester.tap(find.widgetWithText(ElevatedButton, 'Avisar o proprietario'));
    await tester.pumpAndSettle();

    expect(find.textContaining('so fica paga quando'), findsNothing,
        reason: 'a folha fechou');
    expect(find.textContaining('Aguardando a confirmacao'), findsWidgets);
  });
}
