import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/state/competencia_store.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/api_client.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/cadastro_repository.dart';
import 'data/repositories/cobranca_repository.dart';
import 'data/repositories/competencia_repository.dart';
import 'data/repositories/fatura_repository.dart';
import 'data/repositories/fechamento_repository.dart';
import 'data/repositories/imovel_repository.dart';
import 'data/repositories/inquilino_repository.dart';
import 'data/repositories/leitura_repository.dart';
import 'features/auth/view/login_page.dart';
import 'features/auth/viewmodel/login_viewmodel.dart';
import 'features/unidades/viewmodel/painel_viewmodel.dart';

void main() {
  runApp(const AluguelApp());
}

/// Injecao de dependencia: o ApiClient e unico (guarda o token), os
/// repositories sao criados em cima dele e os ViewModels recebem o
/// repository de que precisam.
///
/// O `CompetenciaStore` e o terceiro tipo de provider aqui: nao e
/// repository nem ViewModel de tela, e o mes que o app inteiro esta
/// olhando. Fica global porque o painel troca e as outras telas leem.
class AluguelApp extends StatelessWidget {
  const AluguelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiClient()),
        Provider(create: (ctx) => AuthRepository(ctx.read<ApiClient>())),
        Provider(create: (ctx) => ImovelRepository(ctx.read<ApiClient>())),
        Provider(create: (ctx) => LeituraRepository(ctx.read<ApiClient>())),
        Provider(create: (ctx) => FechamentoRepository(ctx.read<ApiClient>())),
        Provider(create: (ctx) => FaturaRepository(ctx.read<ApiClient>())),
        Provider(create: (ctx) => InquilinoRepository(ctx.read<ApiClient>())),
        Provider(create: (ctx) => CobrancaRepository(ctx.read<ApiClient>())),
        Provider(create: (ctx) => CadastroRepository(ctx.read<ApiClient>())),
        Provider(create: (ctx) => CompetenciaRepository(ctx.read<ApiClient>())),
        ChangeNotifierProvider(
          create: (ctx) => CompetenciaStore(ctx.read<CompetenciaRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => LoginViewModel(ctx.read<AuthRepository>()),
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
      child: MaterialApp(
        title: 'Gestao de aluguel',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const LoginPage(),
      ),
    );
  }
}
