import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/dummy/dummy_data.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/models/wallet_model.dart';
import '../../data/services/account_service.dart';
import '../../data/services/transaction_service.dart';
import '../../data/services/wallet_service.dart';
import '../../data/services/wealth_service.dart';
import '../account/pages/identity_page.dart';
import '../account/widgets/redeem_poin_sheet.dart';
import '../services/service_navigation_helper.dart';
import 'widgets/balance_card.dart';
import 'widgets/cash_flow_card.dart';
import 'widgets/financial_services_section.dart';
import 'widgets/greeting_section.dart';
import 'widgets/home_header.dart';
import 'widgets/quick_actions.dart';
import 'widgets/saving_goal_card.dart';
import 'widgets/security_info_card.dart';
import 'widgets/transaction_history_section.dart';

/// Halaman Beranda FinPay terintegrasi WalletService & TransactionService (Bagian Ali).
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onNavigateToHistory});

  final VoidCallback? onNavigateToHistory;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static final Set<String> _dismissedKycNotifKeys = <String>{};
  String? _scheduledAutoHideKey;
  Timer? _kycNotifTimer;

  @override
  void initState() {
    super.initState();
    WalletService.instance.updateBalance();
    final uid = AccountService.instance.currentUser.userId;
    if (uid.trim().isNotEmpty) {
      AccountService.instance.fetchUserProfile(
        uid,
        fallback: AccountService.instance.currentUser,
      );
    }
  }

  @override
  void dispose() {
    _kycNotifTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoHideKycBanner(String bannerKey) {
    if (_scheduledAutoHideKey == bannerKey ||
        _dismissedKycNotifKeys.contains(bannerKey)) {
      return;
    }
    _scheduledAutoHideKey = bannerKey;
    _kycNotifTimer?.cancel();
    _kycNotifTimer = Timer(const Duration(seconds: 6), () {
      _dismissedKycNotifKeys.add(bannerKey);
      if (mounted) setState(() {});
    });
  }

  void _dismissKycBanner(String bannerKey) {
    _kycNotifTimer?.cancel();
    _dismissedKycNotifKeys.add(bannerKey);
    setState(() {});
  }

  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WalletModel>(
      valueListenable: WalletService.instance.walletNotifier,
      builder: (context, wallet, _) {
        return ValueListenableBuilder(
          valueListenable: TransactionService.instance.transactionsNotifier,
          builder: (context, transactions, __) {
            return SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.maxContentWidth,
                  ),
                  child: CustomScrollView(
                    slivers: [
                      const SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.page,
                          AppSpacing.sm,
                          AppSpacing.page,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(child: HomeHeader()),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.page,
                          AppSpacing.md,
                          AppSpacing.page,
                          AppSpacing.xxxl,
                        ),
                        sliver: SliverList.list(
                          children: _buildSections(wallet, transactions),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildSections(
    WalletModel wallet,
    List<dynamic> transactions,
  ) {
    return [
      ValueListenableBuilder<UserProfileModel>(
        valueListenable: AccountService.instance.userNotifier,
        builder: (context, user, _) {
          final kycBannerKey = '${user.userId}:${user.kycStatus}';
          final showKycNotif = user.userId.isNotEmpty &&
              !_dismissedKycNotifKeys.contains(kycBannerKey);
          if (showKycNotif) {
            _scheduleAutoHideKycBanner(kycBannerKey);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GreetingSection(
                userName: user.fullName,
                membership: user.membership,
                points: user.finPoin,
                onMembershipTap: () => showRedeemPoinSheet(context),
              ),
              if (showKycNotif) ...[
                const SizedBox(height: AppSpacing.md),
                if (!user.isKycVerified)
                  Builder(
                    builder: (_) {
                      final lowerStatus = user.kycStatus.toLowerCase();
                      final isRejected =
                          lowerStatus.contains('upload ulang') ||
                              lowerStatus.contains('ditolak');
                      final bg = isRejected
                          ? AppColors.dangerLight
                          : AppColors.goldLight;
                      final fg = isRejected
                          ? AppColors.danger
                          : const Color(0xFF92400E);
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => const IdentityVerificationPage(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: AppRadius.lgAll,
                            border: Border.all(
                              color: fg.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isRejected
                                    ? Icons.error_outline_rounded
                                    : Icons.hourglass_top_rounded,
                                color: fg,
                                size: 22,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isRejected
                                          ? 'KYC ditolak — Wajib isi ulang NIK'
                                          : 'Data NIK dalam tahap verifikasi',
                                      style: AppTextStyles.label.copyWith(
                                        color: fg,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      isRejected
                                          ? 'Ketuk di sini untuk memasukkan ulang 16 digit NIK kamu.'
                                          : 'Menunggu persetujuan Admin FinPay. Ketuk untuk lihat status.',
                                      style: AppTextStyles.caption.copyWith(
                                        color: fg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _dismissKycBanner(kycBannerKey),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.success,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'NIK telah terverifikasi',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _dismissKycBanner(kycBannerKey),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
      const SizedBox(height: AppSpacing.lg),
      BalanceCard(
        totalBalance: wallet.totalWealth,
        cashBalance: wallet.cashBalance,
        savingBalance: wallet.savingBalance,
        phoneNumber: DummyData.phoneNumber,
      ),
      const SizedBox(height: AppSpacing.lg),
      QuickActions(
        items: DummyData.quickActions,
        onItemTap: (item) {
          ServiceNavigationHelper.openService(
            context,
            item.label,
            onStateChanged: _refresh,
          );
        },
      ),
      const SizedBox(height: AppSpacing.section),
      FinancialServicesSection(
        items: DummyData.services,
        onItemTap: (item) {
          ServiceNavigationHelper.openService(
            context,
            item.label,
            onStateChanged: _refresh,
          );
        },
      ),
      const SizedBox(height: AppSpacing.section),
      _buildHighlightsSection(),
      const SizedBox(height: AppSpacing.section),
      TransactionHistorySection(
        transactions: DummyData.transactions,
        onSeeAllTap: widget.onNavigateToHistory,
      ),
      const SizedBox(height: AppSpacing.section),
      const SecurityInfoCard(),
    ];
  }

  Widget _buildHighlightsSection() {
    final summary = WealthService.instance.calculateCashFlowSummary();
    final firstGoal = WealthService.instance.savingGoals.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Sorotan Keuangan', style: AppTextStyles.h2),
            ),
            Text(
              summary.period,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          onTap: () {
            ServiceNavigationHelper.openService(
              context,
              'Cash Flow',
              onStateChanged: _refresh,
            );
          },
          child: CashFlowCard(
            income: summary.totalIncome,
            expense: summary.totalExpense,
            incomeNote: summary.incomeGrowthLabel,
            expenseNote: summary.expenseRatioLabel,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          onTap: () {
            ServiceNavigationHelper.openService(
              context,
              'Menabung',
              onStateChanged: _refresh,
            );
          },
          child: SavingGoalCard(
            title: firstGoal?.title ?? 'Belum Ada Target Menabung',
            monthlyDebit: firstGoal?.monthlyDebit ?? 0,
            current: firstGoal?.currentAmount ?? 0,
            target: firstGoal?.targetAmount ?? 1,
            eta: firstGoal?.eta ?? '-',
          ),
        ),
      ],
    );
  }
}
