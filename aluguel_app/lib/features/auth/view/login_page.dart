import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../inquilino/view/inquilino_page.dart';
import '../../unidades/view/painel_page.dart';
import '../viewmodel/login_viewmodel.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(text: 'kaua@exemplo.com');
  final _senha = TextEditingController(text: '123456');

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final vm = context.read<LoginViewModel>();
    final ok = await vm.entrar(_email.text, _senha.text);
    if (!mounted) return;
    if (ok) {
      // O perfil decide a tela: o inquilino nao tem acesso as rotas do
      // proprietario, e mandar ele para o painel renderia 403 na cara.
      final proprietario = vm.usuario?.ehProprietario ?? false;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              proprietario ? const PainelPage() : const InquilinoPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Text(
                'Gestao de aluguel',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Entre para ver suas unidades',
                style: AppTypography.body.copyWith(
                  color: AppColors.onPrimaryMuted,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Email', style: AppTypography.caption),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text('Senha', style: AppTypography.caption),
                    const SizedBox(height: 5),
                    TextField(controller: _senha, obscureText: true),
                    if (vm.erro != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSurface,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSmall),
                        ),
                        child: Text(
                          vm.erro!,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.danger),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppButton.primary(
                      label: 'Entrar',
                      carregando: vm.carregando,
                      onPressed: _entrar,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Proprietario: kaua@exemplo.com  ·  Inquilino: maria@exemplo.com\n'
                'Senha dos dois: 123456',
                style: AppTypography.caption
                    .copyWith(color: AppColors.onPrimaryMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
