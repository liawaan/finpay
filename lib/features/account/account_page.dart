import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/services/account_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/transaction_service.dart';
import '../../shared/widgets/pill_badge.dart';
import 'account_data.dart';
import 'account_legal.dart';
import 'pages/cards_page.dart';
import 'pages/change_pin_page.dart';
import 'pages/contact_cs_page.dart';
import 'pages/devices_page.dart';
import 'pages/help_center_page.dart';
import 'pages/identity_page.dart';
import 'pages/legal_page.dart';
import 'pages/limit_page.dart';
import 'pages/my_qr_page.dart';
import 'pages/profile_page.dart';
import 'widgets/account_menu.dart';
import 'widgets/language_sheet.dart';
import 'widgets/profile_card.dart';
import 'widgets/redeem_poin_sheet.dart';
import 'widgets/referral_banner.dart';
import 'widgets/security_score_card.dart';

/// Halaman Akun FinPay terintegrasi [AuthService] & [AccountService] (Bagian Tugas Pidi).
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  // ---------- Navigasi ----------
  /// Buka sub-halaman di atas shell (bottom nav tersembunyi selama di sana).
  Future<T?> _open<T>(Widget page) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(builder: (_) => page),
    );
  }

  Future<void> _openChangePin() async {
    final changed = await _open<bool>(const ChangePinPage());
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN 6 digit berhasil diperbarui!')),
      );
    }
  }

  String _securityHint(UserProfileModel user) {
    if (user.biometricEnabled && user.notificationEnabled) {
      return 'Akunmu terlindungi maksimal. Pertahankan ya!';
    }
    if (!user.biometricEnabled) {
      return 'Aktifkan login biometrik untuk menaikkan skor keamananmu.';
    }
    return 'Nyalakan notifikasi agar transaksi mencurigakan cepat terdeteksi.';
  }

  String? _securityActionLabel(UserProfileModel user) {
    if (!user.biometricEnabled) return 'Aktifkan biometrik';
    if (!user.notificationEnabled) return 'Nyalakan notifikasi';
    return null;
  }

  void _onSecurityAction(UserProfileModel user) {
    if (!user.biometricEnabled) {
      AccountService.instance.updatePreferences(biometricEnabled: true);
    } else if (!user.notificationEnabled) {
      AccountService.instance.updatePreferences(notificationEnabled: true);
    }
  }

  // ---------- Aksi ----------
  Future<void> _pickLanguage(String currentLang) async {
    final selected = await showLanguageSheet(context, current: currentLang);
    if (selected != null && mounted) {
      await AccountService.instance.updatePreferences(language: selected);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        title: Text('Keluar dari FinPay?', style: AppTextStyles.h2),
        content: Text(
          'Kamu perlu login kembali untuk mengakses dompet & layanan FinPay.',
          style: AppTextStyles.bodySmall.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Batal',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Keluar',
              style: AppTextStyles.label.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.instance.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Switch _buildSwitch(bool value, ValueChanged<bool> onChanged) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.primary,
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfileModel>(
      valueListenable: AccountService.instance.userNotifier,
      builder: (context, user, _) {
        return ValueListenableBuilder<List<TransactionModel>>(
          valueListenable: TransactionService.instance.transactionsNotifier,
          builder: (context, transactions, __) {
            return SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.sm,
                      AppSpacing.page,
                      AppSpacing.xxxl,
                    ),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: AppSpacing.lg),
                      ProfileCard(
                        userName: user.fullName,
                        email: user.email,
                        membership: user.membership,
                        points: user.finPoin,
                        memberSince: user.memberSince,
                        transactionCount: transactions.length,
                        nextTierName: AccountDummy.nextTierName,
                        nextTierPoints: AccountDummy.nextTierPoints,
                        onEditTap: () => _open<void>(const ProfilePage()),
                        onRedeemPoinTap: () => showRedeemPoinSheet(context),
                      ),
                  const SizedBox(height: AppSpacing.lg),
                  SecurityScoreCard(
                    score: user.securityScore,
                    hint: _securityHint(user),
                    actionLabel: _securityActionLabel(user),
                    onActionTap: () => _onSecurityAction(user),
                  ),
                  const SizedBox(height: AppSpacing.section),

                  MenuSection(
                    title: 'Akun Saya',
                    children: [
                      MenuTile(
                        icon: Icons.person_outline_rounded,
                        label: 'Profil Saya',
                        subtitle: 'Data diri & kontak (${user.phoneNumber})',
                        onTap: () => _open<void>(const ProfilePage()),
                      ),
                      MenuTile(
                        icon: Icons.credit_card_rounded,
                        label: 'Rekening & Kartu',
                        subtitle: 'Kartu virtual & rekening bank tersimpan',
                        onTap: () => _open<void>(const CardsPage()),
                      ),
                      MenuTile(
                        icon: Icons.speed_rounded,
                        label: 'Limit Transaksi',
                        subtitle:
                            'Limit aktif ${CurrencyFormatter.rupiah(user.dailyLimit)} / hari',
                        onTap: () => _open<void>(const TransactionLimitPage()),
                      ),
                      MenuTile(
                        icon: Icons.badge_outlined,
                        label: 'Verifikasi Identitas',
                        badge: PillBadge(
                          label: user.kycStatus,
                          leadingIcon: user.isKycVerified
                              ? Icons.check_rounded
                              : Icons.hourglass_top_rounded,
                          backgroundColor: user.isKycVerified
                              ? AppColors.successLight
                              : AppColors.goldLight,
                          foregroundColor: user.isKycVerified
                              ? AppColors.success
                              : const Color(0xFFB45309),
                        ),
                        onTap: () =>
                            _open<void>(const IdentityVerificationPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.section),

                  MenuSection(
                    title: 'Keamanan',
                    tone: AccountTone.mint,
                    children: [
                      MenuTile(
                        icon: Icons.lock_outline_rounded,
                        label: 'Ubah PIN',
                        subtitle: 'PIN 6 digit keamanan transaksi',
                        onTap: _openChangePin,
                      ),
                      MenuTile(
                        icon: Icons.fingerprint_rounded,
                        label: 'Login Biometrik',
                        subtitle: 'Masuk dengan sidik jari / Face ID',
                        trailing: _buildSwitch(
                          user.biometricEnabled,
                          (v) => AccountService.instance
                              .updatePreferences(biometricEnabled: v),
                        ),
                      ),
                      MenuTile(
                        icon: Icons.devices_other_rounded,
                        label: 'Perangkat Terpercaya',
                        subtitle: 'Kelola perangkat yang pernah login',
                        onTap: () => _open<void>(const TrustedDevicesPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.section),

                  ReferralBanner(
                    code: user.referralCode,
                    bonusPoints: user.referralBonus,
                    onRedeemTap: () => showRedeemPoinSheet(context),
                  ),
                  const SizedBox(height: AppSpacing.section),

                  MenuSection(
                    title: 'Preferensi',
                    tone: AccountTone.gold,
                    children: [
                      MenuTile(
                        icon: Icons.notifications_none_rounded,
                        label: 'Notifikasi',
                        subtitle: 'Info transaksi & promo',
                        trailing: _buildSwitch(
                          user.notificationEnabled,
                          (v) => AccountService.instance
                              .updatePreferences(notificationEnabled: v),
                        ),
                      ),
                      MenuTile(
                        icon: Icons.language_rounded,
                        label: 'Bahasa',
                        value: user.language,
                        onTap: () => _pickLanguage(user.language),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.section),

                  MenuSection(
                    title: 'Bantuan',
                    children: [
                      MenuTile(
                        icon: Icons.help_outline_rounded,
                        label: 'Pusat Bantuan',
                        subtitle: 'Pertanyaan yang sering diajukan',
                        onTap: () => _open<void>(const HelpCenterPage()),
                      ),
                      MenuTile(
                        icon: Icons.support_agent_rounded,
                        label: 'Hubungi CS',
                        subtitle: 'Chat 24 jam setiap hari',
                        badge: const PillBadge(
                          label: 'Online',
                          backgroundColor: AppColors.successLight,
                          foregroundColor: AppColors.success,
                        ),
                        onTap: () => _open<void>(const ContactCsPage()),
                      ),
                      MenuTile(
                        icon: Icons.description_outlined,
                        label: 'Syarat & Ketentuan',
                        onTap: () => _open<void>(
                          const LegalPage(
                            title: 'Syarat & Ketentuan',
                            sections: AccountLegal.terms,
                          ),
                        ),
                      ),
                      MenuTile(
                        icon: Icons.shield_outlined,
                        label: 'Kebijakan Privasi',
                        onTap: () => _open<void>(
                          const LegalPage(
                            title: 'Kebijakan Privasi',
                            sections: AccountLegal.privacy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.section),

                      _buildLogoutButton(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildFooter(),
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

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(child: Text('Akun', style: AppTextStyles.h1)),
        Material(
          color: AppColors.primaryLight,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => _open<void>(const MyQrPage()),
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.qr_code_2_rounded,
                color: AppColors.primary,
                size: AppSizes.iconMd,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return TextButton.icon(
      onPressed: _confirmLogout,
      icon: const Icon(Icons.logout_rounded, size: AppSizes.iconMd),
      label: Text(
        'Keluar',
        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.danger),
      ),
      style: TextButton.styleFrom(
        backgroundColor: AppColors.dangerLight,
        foregroundColor: AppColors.danger,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: AppSizes.iconSm,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Terdaftar & diawasi OJK • Dijamin LPS',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'FinPay v${AccountDummy.appVersion}',
          style:
              AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
