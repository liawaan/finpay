import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';

/// Indikator 3 langkah pendaftaran: Data diri -> Verifikasi -> Buat PIN.
/// Set [onDark] true kalau ditaruh di atas latar biru (header).
class AuthStepper extends StatelessWidget {
  const AuthStepper({super.key, required this.current, this.onDark = false});

  /// 0 = Data diri, 1 = Verifikasi, 2 = Buat PIN
  final int current;
  final bool onDark;

  static const List<String> _labels = ['Data diri', 'Verifikasi', 'Buat PIN'];

  @override
  Widget build(BuildContext context) {
    final activeBar = onDark ? Colors.white : AppColors.primary;
    final inactiveBar =
        onDark ? Colors.white.withValues(alpha: 0.3) : AppColors.border;
    final activeText = onDark ? Colors.white : AppColors.primary;
    final inactiveText =
        onDark ? Colors.white.withValues(alpha: 0.6) : AppColors.textTertiary;

    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= current ? activeBar : inactiveBar,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _labels[i],
                  style: AppTextStyles.caption.copyWith(
                    color: i <= current ? activeText : inactiveText,
                    fontWeight:
                        i == current ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (i != _labels.length - 1) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}
