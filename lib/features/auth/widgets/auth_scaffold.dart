import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';

/// Kerangka halaman autentikasi: app bar dengan tombol kembali bulat
/// (hanya muncul kalau memang ada halaman sebelumnya), lebar konten
/// dibatasi, ketuk di luar input menutup keyboard, dan area bawah
/// opsional untuk tombol utama.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    this.title,
    this.showBack = true,
    this.bottom,
  });

  final List<Widget> children;
  final String? title;
  final bool showBack;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final canGoBack = showBack && Navigator.of(context).canPop();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: false,
          titleSpacing: canGoBack ? 0 : AppSpacing.page,
          leading: canGoBack
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Material(
                    color: AppColors.surface,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.maybePop(context),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: AppSizes.iconMd,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                )
              : null,
          title: title == null ? null : Text(title!, style: AppTextStyles.h2),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.sm,
                        AppSpacing.page,
                        AppSpacing.xl,
                      ),
                      children: children,
                    ),
                  ),
                  if (bottom != null) bottom!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
