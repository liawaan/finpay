import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../account/widgets/info_note.dart';
import '../data/auth_flow_args.dart';
import '../utils/auth_validators.dart';
import '../utils/phone_input_formatter.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_hero_scaffold.dart';
import '../widgets/auth_routes.dart';
import '../widgets/auth_text_field.dart';
import 'otp_page.dart';

/// Pemulihan Password, langkah 1: masukkan nomor HP untuk dikirimi kode OTP.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _phone = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _next() {
    final error = AuthValidators.phone(_phone.text);
    setState(() => _error = error);
    if (error != null) return;

    Navigator.of(context).push(
      authRoute<void>(
        OtpPage(
          args: AuthFlowArgs(
            purpose: AuthPurpose.resetPassword,
            phone: AuthValidators.normalizePhone(_phone.text),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthHeroScaffold(
      title: 'Lupa Password?',
      subtitle:
          'Masukkan nomor HP yang terdaftar. Kami akan mengirim kode OTP untuk membuat password baru.',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: AuthButton(label: 'Kirim Kode OTP', onPressed: _next),
      ),
      children: [
        AuthTextField(
          label: 'Nomor HP',
          hint: '812-3456-7890',
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: const [PhoneInputFormatter()],
          errorText: _error,
          prefix: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Text('+62', style: AppTextStyles.bodyLarge),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
        ),
        const SizedBox(height: AppSpacing.xl),
        const InfoNote(
          icon: Icons.shield_outlined,
          title: 'Demi keamananmu',
          text: 'FinPay tidak akan pernah meminta password, PIN, atau kode OTP '
              'lewat telepon, chat, atau media sosial. Jangan bagikan ke siapa pun.',
        ),
      ],
    );
  }
}
