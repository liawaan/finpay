import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../main/main_page.dart';
import '../auth_config.dart';
import '../data/auth_repository.dart';
import '../widgets/auth_routes.dart';
import 'onboarding_page.dart';
import 'pin_login_page.dart';

/// Layar pembuka: logo muncul dengan animasi, lalu otomatis menuju:
/// - Beranda, kalau sudah ada sesi login,
/// - Login cepat (PIN), kalau perangkat ini mengingat satu akun,
/// - Onboarding, kalau pengguna baru.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(
      Duration(milliseconds: AuthConfig.skipToHome ? 0 : 1800),
      _goNext,
    );
  }

  Widget _target() {
    if (AuthConfig.skipToHome || authRepository.currentAccount != null) {
      return const MainPage();
    }
    if (authRepository.rememberedAccount != null) return const PinLoginPage();
    return const OnboardingPage();
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(authRoute<void>(_target()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.balanceGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.scale(
                        scale: 0.85 + 0.15 * value,
                        child: child,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: AppRadius.xlAll,
                            boxShadow: AppShadows.glow(AppColors.navy),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 44,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'FinPay',
                          style: AppTextStyles.displayMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Dompet digital & layanan keuangan',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: Text(
                  'Terdaftar & diawasi OJK • Dijamin LPS',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
