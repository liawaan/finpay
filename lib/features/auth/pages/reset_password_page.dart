import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../data/services/auth_service.dart';
import '../data/auth_flow_args.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_banner.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_hero_scaffold.dart';
import '../widgets/auth_routes.dart';
import '../widgets/auth_text_field.dart';
import 'auth_success_page.dart';

/// Pemulihan Password, langkah 3: membuat password baru & konfirmasi password.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.args});

  final AuthFlowArgs args;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  final FocusNode _confirmFocus = FocusNode();

  String? _passwordError;
  String? _confirmError;
  String? _formError;
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    final pwError = AuthValidators.password(_password.text);
    final confirmError = AuthValidators.confirmPassword(
      _password.text,
      _confirmPassword.text,
    );

    setState(() {
      _passwordError = pwError;
      _confirmError = confirmError;
      _formError = null;
    });
    if (pwError != null || confirmError != null) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final ok = await AuthService.instance.resetPasswordByPhone(
      phone: widget.args.phone,
      newPassword: _password.text,
    );
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _saving = false;
        _formError = 'Akun dengan nomor HP ini tidak ditemukan.';
      });
      return;
    }

    setState(() => _saving = false);
    Navigator.of(context).push(
      authRoute<void>(AuthSuccessPage(args: widget.args)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthHeroScaffold(
      title: 'Buat Password Baru',
      subtitle:
          'Masukkan password baru untuk akun FinPay kamu. Pastikan mudah diingat dan aman.',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: AuthButton(
          label: 'Simpan Password Baru',
          loading: _saving,
          onPressed: _submit,
        ),
      ),
      children: [
        AuthTextField(
          label: 'Password Baru',
          hint: 'Minimal 6 karakter',
          controller: _password,
          obscure: true,
          errorText: _passwordError,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _passwordError = null),
          onSubmitted: (_) => _confirmFocus.requestFocus(),
        ),
        const SizedBox(height: AppSpacing.md),
        AuthTextField(
          label: 'Konfirmasi Password Baru',
          hint: 'Ulangi password baru',
          controller: _confirmPassword,
          focusNode: _confirmFocus,
          obscure: true,
          errorText: _confirmError,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _confirmError = null),
          onSubmitted: (_) => _submit(),
        ),
        if (_formError != null) ...[
          const SizedBox(height: AppSpacing.md),
          AuthBanner(message: _formError!),
        ],
      ],
    );
  }
}
