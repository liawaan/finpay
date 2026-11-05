import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/auth_repository.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_routes.dart';
import '../widgets/geometric_art.dart';
import '../widgets/legal_links.dart';
import 'login_page.dart';
import 'pin_login_page.dart';
import 'register_page.dart';

class _Slide {
  const _Slide({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

/// Layar sambutan dengan carousel 3 slide. Ilustrasi dan teks ada di dalam
/// satu halaman PageView, jadi saat digeser keduanya ikut berpindah. Selama
/// bergeser ada efek parallax (gambar bergerak sedikit lebih jauh daripada
/// teks) dan slide yang menjauh memudar.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const List<_Slide> _slides = [
    _Slide(
      title: 'Bayar apa aja, di mana aja',
      subtitle: 'Scan QRIS, transfer, dan bayar tagihan dalam satu aplikasi.',
    ),
    _Slide(
      title: 'Nabung dan atur uang lebih pintar',
      subtitle: 'Bikin target menabung dan pantau arus kas tiap bulan.',
    ),
    _Slide(
      title: 'Aman, resmi, dan terjamin',
      subtitle: 'Diawasi OJK, saldo dijamin LPS, dilindungi PIN & biometrik.',
    ),
  ];

  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;

  bool get _isLast => _index == _slides.length - 1;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Geser otomatis tiap 5 detik. Diulang dari awal setiap kali halaman
  /// berpindah, supaya tidak langsung loncat setelah pengguna menggeser.
  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_index + 1) % _slides.length,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _skip() {
    _controller.animateToPage(
      _slides.length - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push(authRoute<void>(page));
  }

  /// Kalau perangkat ini mengingat akun, "Masuk" langsung ke PIN.
  void _login() {
    _open(authRepository.rememberedAccount != null
        ? const PinLoginPage()
        : const LoginPage());
  }

  /// Posisi halaman saat ini sebagai angka pecahan (mis. 0.4 = 40% menuju
  /// slide kedua). Dipakai untuk efek parallax.
  double get _page {
    if (_controller.hasClients && _controller.position.haveDimensions) {
      return _controller.page ?? _index.toDouble();
    }
    return _index.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) {
                      setState(() => _index = i);
                      _restartTimer();
                    },
                    itemBuilder: (_, i) => AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => _SlideView(
                        slide: _slides[i],
                        variant: i,
                        delta: i - _page,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildDots(),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  child: Column(
                    children: [
                      AuthButton(
                        label: 'Mulai Sekarang',
                        color: AppColors.navy,
                        onPressed: () => _open(const RegisterPage()),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthButton(
                        label: 'Saya sudah punya akun',
                        outlined: true,
                        showArrow: false,
                        onPressed: _login,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: LegalLinks(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: AppRadius.smAll,
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'FinPay',
            style: AppTextStyles.h2.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Visibility(
            visible: !_isLast,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: TextButton(
              onPressed: _skip,
              child: Text(
                'Lewati',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _slides.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == _index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == _index ? AppColors.navy : AppColors.border,
              borderRadius: AppRadius.pillAll,
            ),
          ),
      ],
    );
  }
}

/// Satu halaman carousel: ilustrasi di atas, judul dan deskripsi di bawah.
///
/// [delta] = jarak halaman ini dari halaman yang sedang aktif (0 = aktif,
/// negatif = sudah lewat di kiri, positif = menunggu di kanan).
class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.variant,
    required this.delta,
  });

  final _Slide slide;
  final int variant;
  final double delta;

  @override
  Widget build(BuildContext context) {
    final distance = math.min(delta.abs(), 1.0);

    return Column(
      children: [
        Expanded(
          // Gambar bergerak ekstra mengikuti geseran (parallax) dan memudar.
          child: Transform.translate(
            offset: Offset(delta * 90, 0),
            child: Opacity(
              opacity: 1 - 0.6 * distance,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: GeometricArt(variant: variant),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Transform.translate(
          offset: Offset(delta * 30, 0),
          child: Opacity(
            opacity: 1 - 0.8 * distance,
            child: SizedBox(
              height: 100,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  children: [
                    Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h1,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      slide.subtitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
