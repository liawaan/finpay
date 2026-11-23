import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/image_downloader.dart';
import '../../data/models/transaction_model.dart';
import '../../data/services/account_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/icon_box.dart';
import '../../shared/widgets/pill_badge.dart';

/// Halaman Penuh: Detail & Bukti Struk Transaksi FinPay (bisa dicetak/simpan foto PNG).
class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _isSavingPhoto = false;

  TransactionModel get transaction => widget.transaction;

  bool get _isIncomingTransfer {
    final lowerTitle = transaction.title.toLowerCase();
    final lowerCat = transaction.category.toLowerCase();
    return transaction.isIncoming &&
        (lowerTitle.contains('transfer') ||
            lowerTitle.contains('terima qris') ||
            lowerCat.contains('transfer') ||
            lowerCat.contains('terima qris'));
  }

  bool get _isOutgoingTransfer {
    final lowerTitle = transaction.title.toLowerCase();
    final lowerCat = transaction.category.toLowerCase();
    return !transaction.isIncoming &&
        (lowerTitle.contains('transfer') || lowerCat.contains('transfer'));
  }

  String _extractTaggedField(String? note, String label) {
    if (note == null || note.trim().isEmpty) return '';
    for (final part in note.split('•')) {
      final trimmed = part.trim();
      if (trimmed.toLowerCase().startsWith('${label.toLowerCase()}:')) {
        return trimmed.substring(label.length + 1).trim();
      }
    }
    return '';
  }

  String _resolveSenderInfo() {
    final activeUser = AccountService.instance.currentUser;
    if (_isIncomingTransfer) {
      final fromNote = _extractTaggedField(transaction.note, 'Pengirim');
      if (fromNote.isNotEmpty) return fromNote;
      final title = transaction.title;
      for (final prefix in const ['Transfer masuk dari ', 'Terima QRIS dari ']) {
        if (title.toLowerCase().startsWith(prefix.toLowerCase())) {
          return title.substring(prefix.length).trim();
        }
      }
      return 'Pengguna FinPay';
    }
    return '${activeUser.fullName} (${activeUser.phoneNumber})';
  }

  String _resolveRecipientInfo() {
    final activeUser = AccountService.instance.currentUser;
    if (_isOutgoingTransfer) {
      final fromNote = _extractTaggedField(transaction.note, 'Penerima');
      if (fromNote.isNotEmpty) return fromNote;
      final title = transaction.title;
      for (final prefix in const ['Transfer ke ', 'Transfer QRIS ke ']) {
        if (title.toLowerCase().startsWith(prefix.toLowerCase())) {
          return title.substring(prefix.length).trim();
        }
      }
      return transaction.title;
    }
    return '${activeUser.fullName} (${activeUser.phoneNumber})';
  }

  Future<void> _saveReceiptPhoto() async {
    if (_isSavingPhoto) return;
    setState(() => _isSavingPhoto = true);

    try {
      final boundary = _receiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Area struk belum siap dicetak.');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Gagal mengonversi struk menjadi gambar PNG.');
      }

      final bytes = byteData.buffer.asUint8List();
      final safeRef = transaction.referenceNumber
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'Struk_FinPay_$safeRef.png';
      final savedLocation = await saveReceiptImageToDevice(fileName, bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto struk berhasil disimpan: $savedLocation'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mencetak foto struk: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncoming;
    final isTransfer = _isIncomingTransfer || _isOutgoingTransfer;
    final amountColor = isIncome ? AppColors.success : AppColors.textPrimary;

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
        title: Text(
          isTransfer ? 'Bukti Transfer' : 'Detail Transaksi',
          style: AppTextStyles.h2,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Simpan Foto Struk',
            icon: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
            onPressed: _isSavingPhoto ? null : _saveReceiptPhoto,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          children: [
            // Area Struk yang dapat dicetak menjadi foto PNG
            RepaintBoundary(
              key: _receiptKey,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: AppRadius.xlAll,
                ),
                child: Column(
                  children: [
                    // Main Status & Amount Card
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'STRUK RESMI FINPAY',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.primary,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          IconBox(
                            icon: transaction.icon,
                            size: 64,
                            iconSize: 32,
                            backgroundColor: isIncome
                                ? AppColors.mintLight
                                : AppColors.primaryLight,
                            iconColor: isIncome
                                ? const Color(0xFF0F766E)
                                : AppColors.primary,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            transaction.title,
                            style: AppTextStyles.h2,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          PillBadge(
                            label: '● ${transaction.status}',
                            backgroundColor: AppColors.successLight,
                            foregroundColor: AppColors.success,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            CurrencyFormatter.rupiah(
                              transaction.amount,
                              withSign: true,
                            ),
                            style: AppTextStyles.displayLarge.copyWith(
                              color: amountColor,
                              fontSize: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Detail Rincian Card
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTransfer
                                ? 'Bukti & Rincian Transfer'
                                : 'Rincian Transaksi',
                            style: AppTextStyles.h3,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Divider(color: AppColors.border, height: 1),
                          const SizedBox(height: AppSpacing.md),
                          if (isTransfer) ...[
                            _DetailItemRow(
                              label: 'Jenis Bukti',
                              value: _isIncomingTransfer
                                  ? 'Transfer Masuk'
                                  : 'Transfer Keluar',
                            ),
                            _DetailItemRow(
                              label: 'Dari (Pengirim)',
                              value: _resolveSenderInfo(),
                            ),
                            _DetailItemRow(
                              label: 'Ke (Penerima)',
                              value: _resolveRecipientInfo(),
                            ),
                          ],
                          _DetailItemRow(
                            label: 'Waktu Transaksi',
                            value:
                                '${transaction.dateGroup}, ${transaction.dateTime.split(', ').last}',
                          ),
                          _DetailItemRow(
                            label: 'Kategori',
                            value: transaction.category,
                          ),
                          _DetailItemRow(
                            label: 'Metode Pembayaran',
                            value: transaction.channel,
                          ),
                          _DetailItemRow(
                            label: 'Nomor Referensi',
                            value: transaction.referenceNumber,
                            isCopyable: true,
                            onCopyTap: () {
                              Clipboard.setData(
                                ClipboardData(text: transaction.referenceNumber),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Nomor referensi berhasil disalin!',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          _DetailItemRow(
                            label: 'Biaya Admin',
                            value: transaction.adminFee == 0
                                ? 'Gratis'
                                : CurrencyFormatter.rupiah(transaction.adminFee),
                          ),
                          if (transaction.note != null &&
                              transaction.note!.isNotEmpty)
                            _DetailItemRow(
                              label: 'Catatan',
                              value: transaction.note!,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSavingPhoto ? null : _saveReceiptPhoto,
                icon: _isSavingPhoto
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.photo_library_outlined, color: Colors.white),
                label: Text(
                  _isSavingPhoto
                      ? 'Menyiapkan Foto Struk...'
                      : 'Cetak / Simpan Foto Struk (PNG)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: transaction.referenceNumber),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nomor referensi transaksi berhasil disalin.'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                label: const Text(
                  'Salin Nomor Referensi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItemRow extends StatelessWidget {
  const _DetailItemRow({
    required this.label,
    required this.value,
    this.isCopyable = false,
    this.onCopyTap,
  });

  final String label;
  final String value;
  final bool isCopyable;
  final VoidCallback? onCopyTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (isCopyable) ...[
                  const SizedBox(width: AppSpacing.xs),
                  GestureDetector(
                    onTap: onCopyTap,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
