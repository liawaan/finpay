import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/services/auth_service.dart';
import '../../main/main_page.dart';
import '../data/auth_repository.dart';
import '../utils/auth_validators.dart';
import '../utils/phone_input_formatter.dart';
import '../widgets/auth_banner.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_hero_scaffold.dart';
import '../widgets/auth_routes.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/shake.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

/// Login: tab Nomor HP / Email dengan Password saja.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialPhone});

  /// Nomor HP yang diisi otomatis (mis. setelah pemulihan akun).
  final String? initialPhone;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final FocusNode _pwFocus = FocusNode();

  bool _phoneMode = true;
  bool _loading = false;
  String? _idError;
  String? _pwError;
  String? _formError;
  int _shake = 0;

  Duration? _lockRemaining;
  Timer? _lockTimer;

  bool get _locked => _lockRemaining != null;

  @override
  void initState() {
    super.initState();
    final phone = widget.initialPhone;
    if (phone != null) {
      _idController.text = const PhoneInputFormatter()
          .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: phone))
          .text;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    _pwFocus.dispose();
    _lockTimer?.cancel();
    super.dispose();
  }

  // ---------- Logika ----------

  void _setMode(bool phone) {
    if (_phoneMode == phone) return;
    setState(() {
      _phoneMode = phone;
      _idController.clear();
      _idError = null;
      _formError = null;
    });
  }

  bool _validate() {
    final id = _idController.text;
    final idError =
        _phoneMode ? AuthValidators.phone(id) : AuthValidators.email(id);
    final pwError = AuthValidators.password(_pwController.text);

    setState(() {
      _idError = idError;
      _pwError = pwError;
      _formError = null;
    });
    return idError == null && pwError == null;
  }

  void _startLock(Duration remaining) {
    _lockTimer?.cancel();
    setState(() {
      _lockRemaining = remaining;
      _loading = false;
      _formError = null;
    });
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final left =
          (_lockRemaining ?? Duration.zero) - const Duration(seconds: 1);
      if (left <= Duration.zero) {
        timer.cancel();
        setState(() => _lockRemaining = null);
      } else {
        setState(() => _lockRemaining = left);
      }
    });
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      authRoute<void>(const MainPage()),
      (route) => false,
    );
  }

  Future<void> _submit() async {
    if (_loading || _locked) return;
    if (!_validate()) {
      setState(() => _shake++);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final identifier = _phoneMode
        ? AuthValidators.normalizePhone(_idController.text)
        : _idController.text.trim();

    // Cek status kunci anti brute-force lebih dulu.
    final lockLeft = authRepository.lockRemainingFor(identifier);
    if (lockLeft != null) {
      HapticFeedback.heavyImpact();
      _startLock(lockLeft);
      return;
    }

    // Autentikasi terhadap AuthService & Firebase Firestore (hanya email/no. HP + password).
    final user = await AuthService.instance.loginWithIdentifier(
      identifier: identifier,
      secret: _pwController.text,
    );
    if (!mounted) return;

    if (user != null) {
      _goHome();
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _loading = false;
      _shake++;
      _formError =
          '${_phoneMode ? 'Nomor HP' : 'Email'} atau password salah.';
    });
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return AuthHeroScaffold(
      title: 'Selamat datang kembali',
      subtitle: 'Masuk ke akun FinPay kamu untuk lanjut bertransaksi.',
      children: [
        _buildModeTabs(),
        const SizedBox(height: AppSpacing.md),
        Shake(
          trigger: _shake,
          child: Column(
            children: [
              if (_phoneMode)
                AuthTextField(
                  label: 'Nomor HP',
                  hint: '812-3456-7890',
                  controller: _idController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: const [PhoneInputFormatter()],
                  errorText: _idError,
                  prefix: const _CountryPrefix(),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _pwFocus.requestFocus(),
                )
              else
                AuthTextField(
                  label: 'Email',
                  hint: 'nama@email.com',
                  controller: _idController,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _idError,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _pwFocus.requestFocus(),
                ),
              const SizedBox(height: AppSpacing.md),
              AuthTextField(
                label: 'Password',
                hint: 'Masukkan password',
                controller: _pwController,
                focusNode: _pwFocus,
                obscure: true,
                errorText: _pwError,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context)
                .push(authRoute<void>(const ForgotPasswordPage())),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              'Lupa Password?',
              style: AppTextStyles.label.copyWith(color: AppColors.primary),
            ),
          ),
        ),
        if (_locked) ...[
          const SizedBox(height: AppSpacing.xs),
          AuthBanner(
            icon: Icons.lock_clock_rounded,
            message:
                'Terlalu banyak percobaan. Akun dikunci sementara, coba lagi dalam ${AuthBanner.formatRemaining(_lockRemaining!)}.',
          ),
        ] else if (_formError != null) ...[
          const SizedBox(height: AppSpacing.xs),
          AuthBanner(message: _formError!),
        ],
        const SizedBox(height: AppSpacing.md),
        AuthButton(
          label: 'Masuk',
          loading: _loading,
          onPressed: _locked ? null : _submit,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Belum punya akun FinPay?', style: AppTextStyles.bodySmall),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pushReplacement(authRoute<void>(const RegisterPage())),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                'Daftar',
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeTabs() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeTab(
              label: 'Nomor HP',
              selected: _phoneMode,
              onTap: () => _setMode(true),
            ),
          ),
          Expanded(
            child: _ModeTab(
              label: 'Email',
              selected: !_phoneMode,
              onTap: () => _setMode(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: AppRadius.smAll,
          boxShadow: selected ? AppShadows.card : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Kode negara "+62" di dalam kotak input nomor HP.
class _CountryPrefix extends StatelessWidget {
  const _CountryPrefix();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🇮🇩', style: AppTextStyles.body),
          const SizedBox(width: AppSpacing.xs),
          Text('+62', style: AppTextStyles.bodyLarge),
          const SizedBox(width: AppSpacing.sm),
          Container(width: 1, height: 18, color: AppColors.border),
        ],
      ),
    );
  }
}
