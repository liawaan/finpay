import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/wealth_models.dart';
import '../../../data/services/wealth_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/pill_badge.dart';
import '../../../shared/widgets/rounded_progress_bar.dart';
import '../../services/service_navigation_helper.dart';

/// Kartu Ringkasan Pinjaman FinPay (Bukan banner promosi, melainkan info status kontrak cicilan aktif).
class ActiveLoanSummaryCard extends StatelessWidget {
  const ActiveLoanSummaryCard({super.key, this.onStateChanged});

  final VoidCallback? onStateChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<LoanModel>>(
      valueListenable: WealthService.instance.activeLoansNotifier,
      builder: (context, loans, _) {
        final activeLoan = loans.where((l) => !l.isCompleted).firstOrNull;

        if (activeLoan != null) {
          return _buildActiveLoanContent(context, activeLoan);
        } else {
          return _buildNoLoanContent(context);
        }
      },
    );
  }

  Widget _buildActiveLoanContent(BuildContext context, LoanModel loan) {
    final progress = (loan.paidMonths / loan.tenorMonths).clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      Icons.request_quote_outlined,
                      size: AppSizes.iconSm + 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FinPay Loan Aktif', style: AppTextStyles.h3),
                      Text(
                        'Ref: ${loan.referenceNumber}',
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              const PillBadge(
                label: 'Cicilan Berjalan',
                backgroundColor: AppColors.primaryLight,
                foregroundColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress Tenor Cicilan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progres: Bulan ke-${loan.paidMonths} dari ${loan.tenorMonths}',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$percent%',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          RoundedProgressBar(
            value: progress,
            height: 7,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.md),

          // Detail Angsuran & Sisa Pokok
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cicilan per Bulan',
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.rupiah(loan.monthlyInstallment),
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: AppColors.border,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sisa Total Tagihan',
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.rupiah(loan.remainingBalance),
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ServiceNavigationHelper.openService(
                  context,
                  'Pinjaman',
                  onStateChanged: onStateChanged,
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
              ),
              child: Text(
                'Kelola & Bayar Cicilan',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLoanContent(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.mintLight,
              borderRadius: AppRadius.mdAll,
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Color(0xFF0F766E),
              size: AppSizes.iconMd + 2,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Limit Pinjaman Tersedia', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Hingga Rp 15.000.000 dengan bunga 0.9% p.a.',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton(
            onPressed: () {
              ServiceNavigationHelper.openService(
                context,
                'Pinjaman',
                onStateChanged: onStateChanged,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs + 2,
              ),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
            ),
            child: Text(
              'Ajukan',
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
