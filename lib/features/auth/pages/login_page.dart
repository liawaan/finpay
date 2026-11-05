import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../main/main_page.dart';
import '../data/auth_repository.dart';
import '../utils/auth_validators.dart';
import '../utils/phone_input_formatter.dart';
import '../widgets/auth_banner.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_hero_scaffold.dart';
import '../widgets/auth_routes.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/biometric_sheet.dart';
import '../widgets/shake.dart';
import 'forgot_pin_page.dart';
import 'register_page.dart';

/// Login: tab Nomor HP / Email, PIN atau sandi, "Ingat akun saya", dan
/// pilihan masuk cepat (biometrik, Google, Apple).
///
/// Memakai [authRepository]: ada pembatasan percobaan (5x salah = terkunci
/// sementara) dan pesan error yang tidak membocorkan apakah suatu nomor
/// terdaftar atau tidak.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialPhone});

  /// Nomor HP yang diisi otomatis (mis. setelah reset PIN).
  final String? initialPhone;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String _demoPhone = '812-3456-7890';
  static const String _demoPin = '123456';

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final FocusNode _pwFocus = FocusNode();

  bool _phoneMode = true;
  bool _remember = true;
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

  /// Pintasan untuk demo/presentasi: mengisi akun contoh.
  void _fillDemo() {
    setState(() {
      _phoneMode = true;
      _idController.text = _demoPhone;
      _pwController.text = _demoPin;
      _idError = null;
      _pwError = null;
      _formError = null;
    });
  }

  bool _validate() {
    final id = _idController.text;
    final idError =
        _phoneMode ? AuthValidators.phone(id) : AuthValidators.email(id);
    final pwError = _pwController.text.length < 6 ? 'Minimal 6 karakter' : null;

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

    // DEMO: pura-pura menunggu respons server.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final identifier = _phoneMode
        ? AuthValidators.normalizePhone(_idController.text)
        : _idController.text;
    final result = authRepository.login(
      identifier: identifier,
      secret: _pwController.text,
      remember: _remember,
    );

    switch (result.status) {
      case LoginStatus.success:
        _goHome();
      case LoginStatus.locked:
        HapticFeedback.heavyImpact();
        _startLock(result.lockRemaining);
      case LoginStatus.wrongCredentials:
      case LoginStatus.notFound:
        HapticFeedback.heavyImpact();
        // Pesan sengaja generik agar tidak membocorkan nomor yang terdaftar.
        final warning = (result.status == LoginStatus.wrongCredentials &&
                result.attemptsLeft <= 2)
            ? ' Sisa percobaan: ${result.attemptsLeft}x.'
            : '';
        setState(() {
          _loading = false;
          _shake++;
          _formError =
              '${_phoneMode ? 'Nomor HP' : 'Email'} atau PIN salah.$warning';
        });
    }
  }

  Future<void> _biometric() async {
    if (authRepository.rememberedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Login sekali dengan "Ingat akun saya" aktif untuk memakai biometrik.',
          ),
        ),
      );
      return;
    }
    final ok = await showBiometricSheet(context, title: 'Masuk ke FinPay');
    if (!ok || !mounted) return;
    if (authRepository.signInRemembered() != null) _goHome();
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label belum tersedia (demo)')),
    );
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
                label: 'PIN / Kata Sandi',
                hint: 'Masukkan PIN atau kata sandi',
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
        Row(
          children: [
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: _remember,
                onChanged: (v) => setState(() => _remember = v),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: Colors.white,
                activeTrackColor: AppColors.primary,
              ),
            ),
            Expanded(
              child: Text('Ingat akun saya', style: AppTextStyles.bodySmall),
            ),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .push(authRoute<void>(const ForgotPinPage())),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                'Lupa PIN?',
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
              ),
            ),
          ],
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
          children: [
            const Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('atau masuk dengan', style: AppTextStyles.caption),
            ),
            const Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _QuickButton(
                icon: Icons.fingerprint_rounded,
                label: 'Biometrik',
                onTap: _biometric,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Google',
                onTap: () => _comingSoon('Login Google'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickButton(
                icon: Icons.apple,
                label: 'Apple',
                onTap: () => _comingSoon('Login Apple'),
              ),
            ),
          ],
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
        // Pintasan demo: sengaja kecil dan di paling bawah.
        Center(
          child: TextButton.icon(
            onPressed: _fillDemo,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            icon: const Icon(
              Icons.bolt_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
            label: Text(
              'Isi akun demo',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
          ),
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

/// Tombol kecil untuk pilihan masuk cepat (ikon + label).
class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 22, color: AppColors.textPrimary),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
    );
  }
}
