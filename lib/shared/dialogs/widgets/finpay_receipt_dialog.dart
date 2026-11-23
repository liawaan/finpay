import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/image_downloader.dart';

/// Menampilkan dialog resi / struk digital transaksi FinPay dengan dukungan simpan foto PNG.
Future<void> showFinPayReceiptDialog(
  BuildContext context, {
  required String title,
  required String amountText,
  required Color amountColor,
  required List<Map<String, String>> details,
  String? referenceNumber,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _FinPayReceiptDialog(
      title: title,
      amountText: amountText,
      amountColor: amountColor,
      details: details,
      referenceNumber: referenceNumber,
    ),
  );
}

class _FinPayReceiptDialog extends StatefulWidget {
  const _FinPayReceiptDialog({
    required this.title,
    required this.amountText,
    required this.amountColor,
    required this.details,
    this.referenceNumber,
  });

  final String title;
  final String amountText;
  final Color amountColor;
  final List<Map<String, String>> details;
  final String? referenceNumber;

  @override
  State<_FinPayReceiptDialog> createState() => _FinPayReceiptDialogState();
}

class _FinPayReceiptDialogState extends State<_FinPayReceiptDialog> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _saving = false;

  Future<void> _savePhoto() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Area struk belum siap.');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Gagal membuat foto struk.');
      final safeRef = (widget.referenceNumber ??
              DateTime.now().millisecondsSinceEpoch.toString())
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final saved = await saveReceiptImageToDevice(
        'Struk_FinPay_$safeRef.png',
        byteData.buffer.asUint8List(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto struk disimpan: $saved'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan foto: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      backgroundColor: AppColors.surface,
      contentPadding: const EdgeInsets.all(AppSpacing.xl),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: _receiptKey,
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.successLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 48,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    widget.title,
                    style: AppTextStyles.h2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.amountText,
                    style: AppTextStyles.displayLarge.copyWith(
                      color: widget.amountColor,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: AppSpacing.md),
                  for (final item in widget.details)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['label']!, style: AppTextStyles.caption),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              item['value']!,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _savePhoto,
                  icon: const Icon(Icons.photo_camera_outlined, size: 16),
                  label: Text(_saving ? 'Menyimpan...' : 'Simpan Foto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Selesai'),
                ),
              ),
            ],
          ),
          if (widget.referenceNumber != null &&
              widget.referenceNumber!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.referenceNumber!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Nomor resi ${widget.referenceNumber} disalin!',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 14),
              label: Text(
                'Salin No. Ref (${widget.referenceNumber})',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
