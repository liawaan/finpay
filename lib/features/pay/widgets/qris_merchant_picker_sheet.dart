import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/qris_merchant.dart';
import '../../../data/services/qris_service.dart';
import '../../../shared/widgets/pill_badge.dart';
import 'qris_image_decoder.dart';

/// Menampilkan bottom sheet sumber pemindaian QRIS lengkap:
/// 1. Upload Gambar / Screenshot QRIS dari Galeri Perangkat
/// 2. Tempel / Input Kode QRIS (contoh: hasil "Salin Kode QRIS" dari QRIS Saya milik Ali)
/// 3. Scan QRIS Pengguna FinPay (Transfer Antar Pengguna: Ali Akbar, Reza Pratama, dll)
/// 4. Scan QRIS Merchant Uji Coba
///
/// Mengembalikan string payload EMVCo QRIS (`000201...`) yang dipilih/dipindai.
Future<String?> showQrisScanSourceSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _QrisScanSourceSheet(),
  );
}

/// Wrapper kompatibilitas lama yang mengembalikan [QrisMerchant].
Future<QrisMerchant?> showQrisMerchantPicker(BuildContext context) {
  return showModalBottomSheet<QrisMerchant>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _LegacyMerchantPickerSheet(),
  );
}

class _QrisScanSourceSheet extends StatefulWidget {
  const _QrisScanSourceSheet();

  @override
  State<_QrisScanSourceSheet> createState() => _QrisScanSourceSheetState();
}

class _QrisScanSourceSheetState extends State<_QrisScanSourceSheet> {
  final TextEditingController _pasteController = TextEditingController();
  bool _showPasteField = false;
  bool _isDecodingImage = false;

  @override
  void initState() {
    super.initState();
    QrisService.instance.fetchPublishedUserQrisFromFirebase();
  }

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _handleUploadQrImage() async {
    if (_isDecodingImage) return;
    setState(() => _isDecodingImage = true);
    final decoded = await pickAndDecodeQrisImage();
    if (!mounted) return;
    setState(() => _isDecodingImage = false);

    if (decoded == null) return;
    if (decoded.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Barcode QRIS tidak terbaca dari gambar. Gunakan gambar QR yang lebih jelas atau pilih pengguna di bawah.',
          ),
        ),
      );
      return;
    }

    Navigator.pop(context, decoded.trim());
  }

  Future<void> _handlePasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = (data?.text ?? '').trim();
      if (!mounted) return;
      if (text.isNotEmpty) {
        setState(() {
          _showPasteField = true;
          _pasteController.text = text;
        });
        if (text.contains('000201')) {
          Navigator.pop(context, text);
          return;
        }
      } else {
        setState(() => _showPasteField = true);
      }
    } catch (_) {
      if (mounted) setState(() => _showPasteField = true);
    }
  }

  void _submitPastedQris() {
    final text = _pasteController.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.86;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: AppSpacing.md),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xs,
                ),
                child: Text(
                  'Scan QRIS Pengguna & Galeri',
                  style: AppTextStyles.h2,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text(
                  'Pilih gambar QRIS dari perangkat, tempel kode QRIS teman (misal Ali / Reza), atau pindai langsung.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Baris Tombol Aksi Cepat: Upload Gambar QR & Tempel Kode QRIS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _isDecodingImage ? null : _handleUploadQrImage,
                        icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _isDecodingImage
                              ? 'Membaca QR...'
                              : 'Upload Gambar QR',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.mdAll,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _handlePasteFromClipboard,
                        icon: const Icon(
                          Icons.content_paste_go_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Tempel Kode QRIS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.mdAll,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_showPasteField) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pasteController,
                          decoration: InputDecoration(
                            hintText:
                                'Tempel kode QRIS 000201... di sini',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.mdAll,
                            ),
                          ),
                          onSubmitted: (_) => _submitPastedQris(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      ElevatedButton(
                        onPressed: _submitPastedQris,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.mdAll,
                          ),
                        ),
                        child: const Text(
                          'Baca QR',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ValueListenableBuilder<List<PublishedUserQris>>(
                  valueListenable:
                      QrisService.instance.publishedUserQrisNotifier,
                  builder: (context, _, __) {
                    final peerUsers =
                        QrisService.instance.getPeerUserQrisList();

                    return ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        0,
                        AppSpacing.page,
                        AppSpacing.xl,
                      ),
                      children: [
                        if (peerUsers.isNotEmpty) ...[
                          Text(
                            'QRIS Pengguna FinPay (Transfer Antar Pengguna)',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          for (final peer in peerUsers) ...[
                            _PeerUserQrisTile(
                              peer: peer,
                              onTap: () =>
                                  Navigator.pop(context, peer.qrisString),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        Text(
                          'QRIS Merchant Uji Coba',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        for (final merchant
                            in QrisMerchantCatalog.merchants) ...[
                          _MerchantTile(
                            merchant: merchant,
                            onTap: () =>
                                Navigator.pop(context, merchant.qrisString),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeerUserQrisTile extends StatelessWidget {
  const _PeerUserQrisTile({required this.peer, required this.onTap});

  final PublishedUserQris peer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEFF6FF),
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: AppSizes.serviceIconBox,
                height: AppSizes.serviceIconBox,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QRIS ${peer.userName}',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${peer.phoneNumber} • NMID ${peer.nmid}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PillBadge(
                label: peer.isDynamic
                    ? CurrencyFormatter.rupiah(peer.amount!)
                    : 'Transfer QRIS',
                backgroundColor: peer.isDynamic
                    ? AppColors.successLight
                    : AppColors.primaryLight,
                foregroundColor:
                    peer.isDynamic ? AppColors.success : AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegacyMerchantPickerSheet extends StatelessWidget {
  const _LegacyMerchantPickerSheet();

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadius.pillAll,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xs,
              ),
              child: Text('Pilih QRIS Merchant', style: AppTextStyles.h2),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.xl,
                ),
                itemCount: QrisMerchantCatalog.merchants.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final merchant = QrisMerchantCatalog.merchants[index];
                  return _MerchantTile(
                    merchant: merchant,
                    onTap: () => Navigator.pop(context, merchant),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchantTile extends StatelessWidget {
  const _MerchantTile({required this.merchant, required this.onTap});

  final QrisMerchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: AppSizes.serviceIconBox,
                height: AppSizes.serviceIconBox,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(merchant.icon, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.name,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${merchant.category} • ${merchant.city}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PillBadge(
                label: merchant.isDynamic
                    ? CurrencyFormatter.rupiah(merchant.suggestedAmount)
                    : 'Isi nominal',
                backgroundColor: merchant.isDynamic
                    ? AppColors.successLight
                    : AppColors.goldLight,
                foregroundColor: merchant.isDynamic
                    ? AppColors.success
                    : const Color(0xFF92400E),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
