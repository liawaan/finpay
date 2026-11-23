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
  @override
  void initState() {
    super.initState();
    WalletService.instance.updateBalance();
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
          return GreetingSection(
            userName: user.fullName,
            membership: user.membership,
            points: user.finPoin,
            onMembershipTap: () => showRedeemPoinSheet(context),
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
