import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';

/// Tombol pill besar dengan lingkaran panah di kanan, gaya yang sama di
/// semua halaman autentikasi.
///
/// - [onPressed] null  -> tombol nonaktif (abu-abu).
/// - [loading] true    -> tampil spinner dan tidak bisa diketuk.
/// - [outlined] true   -> versi garis tepi (tombol sekunder).
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.showArrow = true,
    this.color = AppColors.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final bool showArrow;

  /// Warna utama tombol (biru FinPay secara default, navy untuk CTA utama).
  final Color color;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    final Color background = outlined
        ? Colors.transparent
        : (disabled ? AppColors.border : color);
    final Color foreground = outlined
        ? color
        : (disabled ? AppColors.textTertiary : Colors.white);
    final Color arrowBackground = outlined
        ? color.withValues(alpha: 0.12)
        : (disabled
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.2));

    final showGlow = !outlined && !disabled;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.pillAll,
        boxShadow: showGlow ? AppShadows.glow(color) : null,
      ),
      child: Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        shape: StadiumBorder(
          side: outlined
              ? BorderSide(color: color, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: (disabled || loading) ? null : onPressed,
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: foreground,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (showArrow && !loading)
                  Positioned(
                    right: 8,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: arrowBackground,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: AppSizes.iconMd,
                        color: foreground,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
