import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/user_profile_model.dart';
import '../../../data/services/account_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/pill_badge.dart';
import '../widgets/sub_page_scaffold.dart';

/// Verifikasi Identitas (KYC KTP) terintegrasi [AccountService] & verifikasi Admin Dashboard.
class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({super.key});

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends State<IdentityVerificationPage> {
  static const List<String> _benefits = [
    'Limit transaksi hingga Rp 50.000.000 per hari',
    'Tarik tunai dan transfer tanpa batasan tambahan',
    'Prioritas layanan CS FinPay',
  ];

  final TextEditingController _nikController = TextEditingController();
  String? _nikError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _refreshStatusFromFirebase();
  }

  @override
  void dispose() {
    _nikController.dispose();
    super.dispose();
  }

  Future<void> _refreshStatusFromFirebase() async {
    final uid = AccountService.instance.currentUser.userId;
    if (uid.trim().isEmpty) return;
    await AccountService.instance.fetchUserProfile(
      uid,
      fallback: AccountService.instance.currentUser,
    );
  }

  bool _isRejectedStatus(String status) {
    final lower = status.toLowerCase();
    return lower.contains('upload ulang') || lower.contains('ditolak');
  }

  Future<void> _resubmitNik(UserProfileModel user) async {
    if (_submitting) return;
    final cleanNik = _nikController.text.replaceAll(RegExp(r'\D'), '');
    if (cleanNik.length != 16) {
      setState(() => _nikError = 'NIK KTP wajib diisi 16 digit angka.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _nikError = null;
      _submitting = true;
    });

    // Cek apakah NIK baru dipakai oleh user lain di Firebase Firestore.
    final allUsers = await AccountService.instance.fetchAllUsersFromFirestore();
    final nikTakenByOther = allUsers.any(
      (u) =>
          u.userId != user.userId &&
          u.nik.replaceAll(RegExp(r'\D'), '') == cleanNik,
    );
    if (!mounted) return;

    if (nikTakenByOther) {
      setState(() {
        _submitting = false;
        _nikError = 'NIK sudah terpakai';
      });
      return;
    }

    await AuthService.instance.updateKycStatus(
      status: 'Menunggu Verifikasi',
      nik: cleanNik,
    );
    if (!mounted) return;

    _nikController.clear();
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Data NIK baru berhasil dikirim. Menunggu verifikasi Admin FinPay.',
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfileModel>(
      valueListenable: AccountService.instance.userNotifier,
      builder: (context, user, _) {
        final isVerified = user.isKycVerified;
        final isRejected = !isVerified && _isRejectedStatus(user.kycStatus);

        final bannerBg = isVerified
            ? AppColors.successLight
            : (isRejected ? AppColors.dangerLight : AppColors.goldLight);
        final bannerFg = isVerified
            ? AppColors.success
            : (isRejected ? AppColors.danger : const Color(0xFF92400E));
        final bannerIcon = isVerified
            ? Icons.verified_rounded
            : (isRejected
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded);

        return SubPageScaffold(
          title: 'Verifikasi Identitas',
          children: [
            // Banner Notifikasi Status NIK
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: bannerBg,
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: bannerFg.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(bannerIcon, color: bannerFg),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isVerified
                          ? 'NIK telah terverifikasi oleh Admin FinPay.'
                          : (isRejected
                              ? 'Verifikasi KYC ditolak oleh Admin. Kamu wajib mengisi ulang data NIK (16 digit) agar dapat diverifikasi kembali.'
                              : 'Data NIK kamu sedang dalam tahap verifikasi oleh Admin FinPay. Mohon tunggu hingga disetujui.'),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: bannerFg,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Form Wajib Isi Ulang NIK jika KYC ditolak Admin
            if (isRejected) ...[
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Isi Ulang Data NIK (Wajib)', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Pastikan 16 digit NIK KTP sesuai identitas asli kamu.',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _nikController,
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) {
                        if (_nikError != null) {
                          setState(() => _nikError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'NIK KTP Baru (16 Digit)',
                        hintText: 'Contoh: 3201234567890001',
                        counterText: '',
                        errorText: _nikError,
                        prefixIcon: const Icon(
                          Icons.badge_outlined,
                          color: AppColors.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.mdAll,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _submitting ? null : () => _resubmitNik(user),
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                        label: Text(
                          _submitting
                              ? 'Mengirim Data NIK...'
                              : 'Kirim Ulang NIK untuk Verifikasi',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bannerBg,
                      ),
                      child: Icon(
                        isVerified
                            ? Icons.verified_user_rounded
                            : (isRejected
                                ? Icons.gpp_bad_rounded
                                : Icons.hourglass_top_rounded),
                        size: 34,
                        color: bannerFg,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      isVerified
                          ? 'NIK telah terverifikasi'
                          : (isRejected
                              ? 'KYC Ditolak — Isi Ulang NIK'
                              : 'Data NIK dalam tahap verifikasi'),
                      style: AppTextStyles.h1,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isVerified
                          ? 'Akun atas nama ${user.fullName} (NIK ${user.nik}) telah diverifikasi oleh Admin FinPay.'
                          : (isRejected
                              ? 'NIK sebelumnya (${user.nik}) ditolak oleh Admin. Silakan masukkan NIK yang benar di atas.'
                              : 'Data NIK (${user.nik}) atas nama ${user.fullName} sedang menunggu persetujuan Admin FinPay.'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PillBadge(
                      label: isVerified
                          ? 'NIK telah terverifikasi'
                          : (isRejected
                              ? 'Wajib Isi Ulang NIK'
                              : 'Dalam Tahap Verifikasi'),
                      leadingIcon: isVerified
                          ? Icons.verified_rounded
                          : (isRejected
                              ? Icons.warning_amber_rounded
                              : Icons.hourglass_bottom_rounded),
                      backgroundColor: bannerBg,
                      foregroundColor: bannerFg,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            Text('Manfaat Akun Terverifikasi', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: [
                  for (final benefit in _benefits)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs + 2,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: AppSizes.iconMd,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              benefit,
                              style: AppTextStyles.body.copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
