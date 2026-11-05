import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/icon_box.dart';
import '../../main/main_page.dart';
import '../data/auth_flow_args.dart';
import '../widgets/auth_routes.dart';
import '../widgets/auth_scaffold.dart';
import 'login_page.dart';

/// Layar sukses di akhir alur. Isinya menyesuaikan tujuan:
/// - daftar akun -> sambutan + bonus, lanjut ke Beranda,
/// - reset PIN   -> konfirmasi, lanjut ke halaman Masuk.
/// Tombol kembali dimatikan supaya langkah sebelumnya tidak terulang.
class AuthSuccessPage extends StatelessWidget {
  const AuthSuccessPage({super.key, required this.args});

  final AuthFlowArgs args;

  bool get _isReset => args.purpose == AuthPurpose.resetPin;

  String get _firstName {
    final parts = (args.name ?? '').trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'kamu' : parts.first;
  }

  void _continue(BuildContext context) {
    final Widget next = _isReset
        ? LoginPage(initialPhone: args.phone)
        : const MainPage();

    Navigator.of(context).pushAndRemoveUntil(
      authRoute<void>(next),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AuthScaffold(
        showBack: false,
        bottom: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          child: ElevatedButton(
            onPressed: () => _continue(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
            ),
            child: Text(
              _isReset ? 'Masuk Sekarang' : 'Mulai Pakai FinPay',
              style: AppTextStyles.bodyLarge.copyWith(color: Colors.white),
            ),
          ),
        ),
        children: [
          const SizedBox(height: AppSpacing.xxxl),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.successLight,
                ),
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            _isReset ? 'PIN berhasil diubah!' : 'Akun berhasil dibuat!',
            textAlign: TextAlign.center,
            style: AppTextStyles.displayMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _isReset
                ? 'PIN barumu sudah aktif. Silakan masuk dengan PIN tersebut.'
                : 'Selamat datang di FinPay, $_firstName. Yuk mulai atur keuanganmu.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
          if (!_isReset) ...[
            const SizedBox(height: AppSpacing.xxl),
            AppCard(
              child: Row(
                children: [
                  const IconBox(
                    icon: Icons.card_giftcard_rounded,
                    size: 44,
                    backgroundColor: AppColors.goldLight,
                    iconColor: Color(0xFF92400E),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonus selamat datang',
                          style: AppTextStyles.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          args.referral == null
                              ? 'Kamu dapat 100 FinPoin untuk transaksi pertama.'
                              : 'Kode ${args.referral} diterapkan. Kamu dapat 600 FinPoin!',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
