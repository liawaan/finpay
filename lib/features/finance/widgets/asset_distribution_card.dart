import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/pill_badge.dart';

/// Kartu "Distribusi Aset" ala GoPay Portofolio.
/// Menampilkan alokasi kekayaan bersih antara Saldo FinPay Cash (Likuid)
/// dan Saldo Tabungan (Investasi/Simpanan).
class AssetDistributionCard extends StatelessWidget {
  const AssetDistributionCard({
    super.key,
    required this.cashBalance,
    required this.savingBalance,
  });

  final int cashBalance;
  final int savingBalance;

  int get totalWealth => cashBalance + savingBalance;

  double get cashRatio =>
      totalWealth <= 0 ? 0.0 : (cashBalance / totalWealth).clamp(0.0, 1.0);
  double get savingRatio =>
      totalWealth <= 0 ? 0.0 : (savingBalance / totalWealth).clamp(0.0, 1.0);

  int get cashPct => (cashRatio * 100).round();
  int get savingPct => totalWealth <= 0 ? 0 : 100 - cashPct;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: const Icon(
                      Icons.pie_chart_rounded,
                      size: AppSizes.iconSm + 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Distribusi Portofolio', style: AppTextStyles.h3),
                      Text(
                        'Alokasi dana & aset aktifmu',
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const PillBadge(
                label: 'Aset Aktif',
                backgroundColor: AppColors.mintLight,
                foregroundColor: Color(0xFF0F766E),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Horizontal Segmented Allocation Bar
          _buildAllocationBar(),
          const SizedBox(height: AppSpacing.md),

          // Detail Tiles: Cash vs Tabungan
          Row(
            children: [
              Expanded(
                child: _AssetDetailBox(
                  dotColor: AppColors.primary,
                  label: 'FinPay Cash',
                  percent: '$cashPct%',
                  amount: CurrencyFormatter.rupiah(cashBalance),
                  sublabel: 'Likuid / Siap Pakai',
                  bgColor: AppColors.primarySoft,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _AssetDetailBox(
                  dotColor: AppColors.gold,
                  label: 'Tabungan FinPay',
                  percent: '$savingPct%',
                  amount: CurrencyFormatter.rupiah(savingBalance),
                  sublabel: 'Bunga 4.5% p.a.',
                  bgColor: AppColors.goldLight.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Insight Finansial Kecil
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: AppColors.gold,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    totalWealth <= 0
                        ? 'Mulai isi saldo atau menabung untuk membentuk portofolio ideal.'
                        : cashPct > 80
                            ? 'Pindahkan sebagian dana ke Tabungan untuk mendapatkan imbal hasil optimal.'
                            : 'Alokasi portofolio seimbang antara kebutuhan harian dan simpanan.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationBar() {
    if (totalWealth <= 0) {
      return Container(
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: AppRadius.pillAll,
        ),
      );
    }

    final cashFlex = (cashRatio * 1000).round();
    final savingFlex = (savingRatio * 1000).round();

    return ClipRRect(
      borderRadius: AppRadius.pillAll,
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            if (cashFlex > 0)
              Expanded(
                flex: cashFlex,
                child: Container(color: AppColors.primary),
              ),
            if (cashFlex > 0 && savingFlex > 0)
              const SizedBox(width: 2),
            if (savingFlex > 0)
              Expanded(
                flex: savingFlex,
                child: Container(color: AppColors.gold),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssetDetailBox extends StatelessWidget {
  const _AssetDetailBox({
    required this.dotColor,
    required this.label,
    required this.percent,
    required this.amount,
    required this.sublabel,
    required this.bgColor,
  });

  final Color dotColor;
  final String label;
  final String percent;
  final String amount;
  final String sublabel;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Text(
                percent,
                style: AppTextStyles.labelSmall.copyWith(
                  color: dotColor == AppColors.gold ? const Color(0xFFB45309) : dotColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            sublabel,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
