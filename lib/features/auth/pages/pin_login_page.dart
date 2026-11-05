import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../main/main_page.dart';
import '../data/auth_repository.dart';
import '../widgets/auth_banner.dart';
import '../widgets/auth_routes.dart';
import '../widgets/auth_hero_scaffold.dart';
import '../widgets/biometric_sheet.dart';
import '../widgets/pin_pad.dart';
import '../widgets/shake.dart';
import 'forgot_pin_page.dart';
import 'login_page.dart';

/// Login cepat untuk pengguna yang akunnya "diingat" di perangkat ini:
/// cukup masukkan PIN 6 digit (atau biometrik), seperti di aplikasi
/// dompet digital populer.
class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  static const int _length = 6;

  final Account? _account = authRepository.rememberedAccount;

  String _pin = '';
  String? _error;
  int _shake = 0;
  Duration? _lockRemaining;
  Timer? _lockTimer;

  bool get _locked => _lockRemaining != null;

  @override
  void initState() {
    super.initState();
    final account = _account;
    if (account == null) {
      // Tidak ada akun yang diingat: arahkan ke login biasa.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context)
            .pushReplacement(authRoute<void>(const LoginPage()));
      });
      return;
    }
    // Kalau sebelumnya sudah terkunci, lanjutkan hitung mundurnya.
    final remaining = authRepository.lockRemainingFor(account.phone);
    if (remaining != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startLock(remaining);
      });
    }
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  void _startLock(Duration remaining) {
    _lockTimer?.cancel();
    setState(() {
      _lockRemaining = remaining;
      _pin = '';
      _error = null;
    });
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final left = (_lockRemaining ?? Duration.zero) - const Duration(seconds: 1);
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

  void _onDigit(String digit) {
    if (_pin.length >= _length || _locked) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == _length) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) _verify();
      });
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _verify() {
    final result = authRepository.loginRemembered(_pin);

    switch (result.status) {
      case LoginStatus.success:
        _goHome();
      case LoginStatus.locked:
        HapticFeedback.heavyImpact();
        _startLock(result.lockRemaining);
      case LoginStatus.wrongCredentials:
      case LoginStatus.notFound:
        HapticFeedback.heavyImpact();
        setState(() {
          _pin = '';
          _shake++;
          _error = result.attemptsLeft > 0 && result.attemptsLeft <= 2
              ? 'PIN salah. Sisa percobaan: ${result.attemptsLeft}x.'
              : 'PIN salah. Coba lagi.';
        });
    }
  }

  Future<void> _biometric() async {
    if (_locked) return;
    final ok = await showBiometricSheet(context, title: 'Masuk ke FinPay');
    if (!ok || !mounted) return;
    if (authRepository.signInRemembered() != null) _goHome();
  }

  void _switchAccount() {
    authRepository.forgetRememberedAccount();
    Navigator.of(context).pushReplacement(authRoute<void>(const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    if (account == null) {
      return const Scaffold(backgroundColor: AppColors.background);
    }

    return AuthHeroScaffold(
      title: 'Halo lagi, ${account.firstName}!',
      subtitle: account.maskedPhone,
      trailing: AuthAvatarBadge(initials: account.initials),
      children: [
        Center(
          child: Text(
            'Masukkan PIN FinPay kamu',
            style: AppTextStyles.label,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Shake(
          trigger: _shake,
          child: PinDots(
            length: _length,
            filled: _pin.length,
            hasError: _error != null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_locked)
          AuthBanner(
            icon: Icons.lock_clock_rounded,
            message:
                'Terlalu banyak percobaan. Coba lagi dalam ${AuthBanner.formatRemaining(_lockRemaining!)}.',
          )
        else
          SizedBox(
            height: 28,
            child: Center(
              child: Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: AppColors.danger),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        PinKeypad(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
          enabled: !_locked,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _biometric,
              icon: const Icon(Icons.fingerprint_rounded, size: AppSizes.iconMd),
              label: Text(
                'Biometrik',
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .push(authRoute<void>(const ForgotPinPage())),
              child: Text(
                'Lupa PIN?',
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
        Center(
          child: TextButton(
            onPressed: _switchAccount,
            child: Text(
              'Bukan ${account.firstName}? Ganti akun',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}
