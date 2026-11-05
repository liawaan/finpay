import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import 'geometric_art.dart';

/// Kerangka halaman form autentikasi: header bergradasi biru (senada kartu
/// profil di halaman Akun) dengan bagian bawah melengkung halus dan soft
/// shadow, lalu form di bawahnya. Seluruh halaman bisa di-scroll, jadi tetap
/// nyaman saat keyboard terbuka.
///
/// [bottom] (mis. tombol utama) menempel di bawah layar.
class AuthHeroScaffold extends StatelessWidget {
  const AuthHeroScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.bottom,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;

  /// Widget di kanan atas header, sejajar tombol kembali.
  final Widget? trailing;
  final List<Widget> children;
  final Widget? bottom;
  final bool showBack;

  /// Kelengkungan sudut bawah header.
  static const double _headerRadius = 36;

  @override
  Widget build(BuildContext context) {
    final canGoBack = showBack && Navigator.of(context).canPop();
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      _Header(
                        topInset: topInset,
                        title: title,
                        subtitle: subtitle,
                        trailing: trailing,
                        canGoBack: canGoBack,
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.page,
                          AppSpacing.xl,
                          AppSpacing.page,
                          AppSpacing.xl + (bottom == null ? bottomInset : 0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: children,
                        ),
                      ),
                    ],
                  ),
                ),
                if (bottom != null)
                  Container(
                    width: double.infinity,
                    color: AppColors.background,
                    child: SafeArea(top: false, child: bottom!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.topInset,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.canGoBack,
  });

  final double topInset;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool canGoBack;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(
      bottom: Radius.circular(AuthHeroScaffold._headerRadius),
    );

    return DecoratedBox(
      // Soft shadow di bawah header supaya transisi ke form terasa lembut.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.balanceGradient),
          child: Stack(
            children: [
              const Positioned(
                top: -30,
                right: -50,
                child: GeometricCorner(),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  topInset + AppSpacing.md,
                  AppSpacing.page,
                  AppSpacing.xl + AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          if (canGoBack)
                            Material(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => Navigator.maybePop(context),
                                child: const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    size: AppSizes.iconMd,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (trailing != null) trailing!,
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      title,
                      style: AppTextStyles.displayMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs + 2),
                      Text(
                        subtitle!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lingkaran inisial putih untuk ditaruh di kanan atas header.
class AuthAvatarBadge extends StatelessWidget {
  const AuthAvatarBadge({super.key, required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Text(
        initials,
        style: AppTextStyles.bodyLarge.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
