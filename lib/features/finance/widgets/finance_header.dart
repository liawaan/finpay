import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/pill_badge.dart';

/// Header khusus halaman Keuangan: Judul & Indicator Kesehatan Finansial.
class FinanceHeader extends StatelessWidget {
  const FinanceHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Keuangan & Portofolio', style: AppTextStyles.h1),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Kelola saldo, anggaran, dan target impianmu',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const PillBadge(
          label: 'Kondisi Sehat 👍',
          backgroundColor: AppColors.successLight,
          foregroundColor: AppColors.success,
        ),
      ],
    );
  }
}
