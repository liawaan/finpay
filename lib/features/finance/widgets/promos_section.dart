import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/wealth_models.dart';
import '../../../data/services/wealth_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/pill_badge.dart';
import '../../../shared/widgets/section_header.dart';
import '../../services/service_navigation_helper.dart';

/// Section Promo & Keuntungan FinPay yang kaya, padat, dan interaktif.
class PromosSection extends StatefulWidget {
  const PromosSection({super.key, this.onStateChanged});

  final VoidCallback? onStateChanged;

  @override
  State<PromosSection> createState() => _PromosSectionState();
}

class _PromosSectionState extends State<PromosSection> {
  String _selectedCategory = 'Semua';

  static const List<String> _categories = [
    'Semua',
    'Cashback',
    'Diskon Tagihan',
    'Investasi',
  ];

  @override
  void initState() {
    super.initState();
    if (WealthService.instance.promosNotifier.value.length <
        WealthService.initialPromos.length) {
      WealthService.instance.promosNotifier.value =
          List<PromoModel>.from(WealthService.initialPromos);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PromoModel>>(
      valueListenable: WealthService.instance.promosNotifier,
      builder: (context, promos, _) {
        final filteredPromos = _selectedCategory == 'Semua'
            ? promos
            : promos.where((p) => p.category == _selectedCategory).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            SectionHeader(
              title: 'Promo & Keuntungan Fin',
              actionLabel: 'Lihat Semua (${promos.length})',
              onActionTap: () => ServiceNavigationHelper.openService(
                context,
                'Promo',
                onStateChanged: widget.onStateChanged,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Mini Highlight Banner Promo
            _buildPromoBanner(context),
            const SizedBox(height: AppSpacing.md),

            // Filter Chips Kategori
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = category);
                        }
                      },
                      labelStyle: AppTextStyles.labelSmall.copyWith(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.pillAll,
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Daftar Kartu Promo
            for (var i = 0; i < filteredPromos.length; i++) ...[
              _PromoCard(
                promo: filteredPromos[i],
                onClaimTap: () async {
                  if (!filteredPromos[i].isClaimed) {
                    await WealthService.instance.claimPromo(filteredPromos[i].id);
                    widget.onStateChanged?.call();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Voucher "${filteredPromos[i].code}" berhasil diklaim!',
                          ),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
              if (i != filteredPromos.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPromoBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.celebration_rounded,
              color: AppColors.gold,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pesta Cuan Akhir Tahun 🎉',
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Klaim semua voucher & hemat hingga Rp 150.000',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.promo,
    required this.onClaimTap,
  });

  final PromoModel promo;
  final VoidCallback onClaimTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: promo.color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(
                  promo.icon,
                  color: promo.color,
                  size: AppSizes.iconMd + 2,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PillBadge(
                          label: promo.category,
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: AppColors.primary,
                        ),
                        Text(
                          promo.validity,
                          style: AppTextStyles.caption.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      promo.title,
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      promo.description,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.xs + 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppRadius.smAll,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      promo.code,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              promo.isClaimed
                  ? const PillBadge(
                      label: 'Terklaim ✓',
                      backgroundColor: AppColors.successLight,
                      foregroundColor: AppColors.success,
                    )
                  : ElevatedButton(
                      onPressed: onClaimTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.xs,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.pillAll,
                        ),
                      ),
                      child: Text(
                        'Klaim Voucher',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
