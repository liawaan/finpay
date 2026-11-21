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

/// Kartu Pos Anggaran & Smart Budgeting (Spending Pockets) ala Bank Jago & Jenius.
/// Berjalan murni secara lokal di Flutter tanpa backend eksternal.
class SmartBudgetingCard extends StatelessWidget {
  const SmartBudgetingCard({super.key, this.onStateChanged});

  final VoidCallback? onStateChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<BudgetCategoryModel>>(
      valueListenable: WealthService.instance.budgetsNotifier,
      builder: (context, budgets, _) {
        final totalLimit =
            budgets.fold<int>(0, (sum, b) => sum + b.monthlyLimit);
        final totalSpent =
            budgets.fold<int>(0, (sum, b) => sum + b.spentAmount);
        final totalRemaining = (totalLimit - totalSpent).clamp(0, totalLimit);
        final overallProgress =
            totalLimit <= 0 ? 0.0 : (totalSpent / totalLimit).clamp(0.0, 1.0);
        final overallPercent = (overallProgress * 100).round();

        final isSafe = overallProgress < 0.8;

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                          Icons.donut_small_rounded,
                          size: AppSizes.iconSm + 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pos Anggaran Bulanan', style: AppTextStyles.h3),
                          Text(
                            'Kontrol batas belanja aman',
                            style: AppTextStyles.caption.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  PillBadge(
                    label: isSafe ? 'Terkendali 👍' : 'Waspada ⚠️',
                    backgroundColor:
                        isSafe ? AppColors.successLight : AppColors.goldLight,
                    foregroundColor:
                        isSafe ? AppColors.success : const Color(0xFFB45309),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Overall Budget Summary Box
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sisa Anggaran Aman',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              CurrencyFormatter.rupiah(totalRemaining),
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total Budget: ${CurrencyFormatter.rupiah(totalLimit)}',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Terpakai $overallPercent%',
                              style: AppTextStyles.caption.copyWith(
                                color: isSafe
                                    ? AppColors.primary
                                    : AppColors.danger,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    RoundedProgressBar(
                      value: overallProgress,
                      height: 7,
                      color: isSafe ? AppColors.primary : AppColors.danger,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Category List
              for (var i = 0; i < budgets.length; i++) ...[
                _BudgetPocketItem(
                  budget: budgets[i],
                  onTap: () => _showEditBudgetDialog(context, budgets[i]),
                ),
                if (i != budgets.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
              ],
              const SizedBox(height: AppSpacing.md),

              // Footer Tip & Adjust Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.touch_app_outlined,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ketuk pos untuk ubah limit',
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => _showEditBudgetDialog(context, budgets.first),
                    borderRadius: AppRadius.pillAll,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        'Atur Limit ›',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditBudgetDialog(BuildContext context, BudgetCategoryModel budget) {
    final controller =
        TextEditingController(text: budget.monthlyLimit.toString());

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        title: Row(
          children: [
            Icon(budget.icon, color: budget.color, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Batas ${budget.title}',
                style: AppTextStyles.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengeluaran bulan ini: ${CurrencyFormatter.rupiah(budget.spentAmount)}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Ubah Limit Anggaran Bulanan (Rp):',
              style: AppTextStyles.labelSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: 'Rp ',
                hintText: 'Cth: 2000000',
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newLimit = int.tryParse(controller.text.trim()) ?? 0;
              if (newLimit > 0) {
                WealthService.instance
                    .updateBudgetLimit(budget.id, newLimit);
                onStateChanged?.call();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Limit "${budget.title}" diubah jadi ${CurrencyFormatter.rupiah(newLimit)}',
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _BudgetPocketItem extends StatelessWidget {
  const _BudgetPocketItem({
    required this.budget,
    required this.onTap,
  });

  final BudgetCategoryModel budget;
  final VoidCallback onTap;

  Color get progressColor {
    if (budget.isOverBudget) return AppColors.danger;
    if (budget.progress >= 0.8) return AppColors.gold;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: budget.color.withValues(alpha: 0.12),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(budget.icon, color: budget.color, size: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.title,
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${CurrencyFormatter.rupiah(budget.spentAmount)} / ${CurrencyFormatter.rupiah(budget.monthlyLimit)}',
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${budget.percentage}%',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            RoundedProgressBar(
              value: budget.progress,
              height: 5,
              color: progressColor,
              backgroundColor: AppColors.background,
            ),
          ],
        ),
      ),
    );
  }
}
