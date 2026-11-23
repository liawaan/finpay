import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/wealth_models.dart';
import '../../data/services/wealth_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/pill_badge.dart';

/// Halaman Penuh 8: Promo & Voucher FinPay terintegrasi [WealthService] & koleksi `promos` (Bagian Tugas Pidi).
class PromosPage extends StatefulWidget {
  const PromosPage({super.key});

  @override
  State<PromosPage> createState() => _PromosPageState();
}

class _PromosPageState extends State<PromosPage> {
  String _selectedCategory = 'Semua';

  final List<String> _categories = const [
    'Semua',
    'Cashback',
    'Diskon Tagihan',
  ];

  Future<void> _claimPromo(PromoModel promo) async {
    try {
      final updated = await WealthService.instance.claimPromo(promo.id);
      await Clipboard.setData(ClipboardData(text: updated.code));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Voucher "${updated.code}" berhasil diklaim & disalin ke clipboard!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PromoModel>>(
      valueListenable: WealthService.instance.promosNotifier,
      builder: (context, promos, _) {
        final visiblePromos =
            promos.where((p) => p.category != 'Investasi').toList();
        final items = _selectedCategory == 'Semua'
            ? visiblePromos
            : visiblePromos
                .where((p) => p.category == _selectedCategory)
                .toList();
        final claimedCount = visiblePromos.where((p) => p.isClaimed).length;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Promo & Voucher FinPay', style: AppTextStyles.h2),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Center(
                  child: PillBadge(
                    label: '$claimedCount Diklaim',
                    backgroundColor: AppColors.successLight,
                    foregroundColor: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.maxContentWidth,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Promo Utama
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        gradient: AppColors.balanceGradient,
                        borderRadius: AppRadius.xlAll,
                        boxShadow: AppShadows.glow(AppColors.primary),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.card_giftcard_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PROMO SPESIAL OKTOBER 🎉',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.white70,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pakai Voucher & Hemat Hingga Rp 100.000!',
                                  style: AppTextStyles.h2.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),

                    // Category Chips
                    Text('Kategori Promo', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: [
                          for (final cat in _categories) ...[
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = cat),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedCategory == cat
                                      ? AppColors.primary
                                      : AppColors.surface,
                                  borderRadius: AppRadius.pillAll,
                                  border: Border.all(
                                    color: _selectedCategory == cat
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                  boxShadow: _selectedCategory == cat
                                      ? AppShadows.glow(AppColors.primary)
                                      : AppShadows.card,
                                ),
                                child: Text(
                                  cat,
                                  style: AppTextStyles.label.copyWith(
                                    color: _selectedCategory == cat
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),

                    // List Banner Promos
                    for (final promo in items) ...[
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: promo.color.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    promo.icon,
                                    size: 28,
                                    color: promo.color,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        promo.title,
                                        style: AppTextStyles.h3,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          PillBadge(
                                            label: promo.category,
                                            backgroundColor:
                                                AppColors.primaryLight,
                                            foregroundColor: AppColors.primary,
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          if (promo.isClaimed)
                                            const PillBadge(
                                              label: 'Sudah Diklaim',
                                              leadingIcon: Icons.check_rounded,
                                              backgroundColor:
                                                  AppColors.successLight,
                                              foregroundColor:
                                                  AppColors.success,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              promo.description,
                              style:
                                  AppTextStyles.bodySmall.copyWith(height: 1.5),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Divider(color: AppColors.border, height: 1),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${promo.validity} • Kode: ${promo.code}',
                                  style: AppTextStyles.caption
                                      .copyWith(fontSize: 10),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _claimPromo(promo),
                                  icon: Icon(
                                    promo.isClaimed
                                        ? Icons.check_circle_rounded
                                        : Icons.copy_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    promo.isClaimed
                                        ? 'Salin Ulang'
                                        : 'Klaim Promo',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: promo.isClaimed
                                        ? AppColors.success
                                        : AppColors.primary,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
