import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../account/account_legal.dart';
import '../../account/pages/legal_page.dart';

/// Kalimat persetujuan dengan tautan Syarat & Ketentuan dan Kebijakan
/// Privasi yang bisa diketuk (membuka halaman dokumen di fitur Akun).
class LegalLinks extends StatelessWidget {
  const LegalLinks({
    super.key,
    this.prefix = 'Dengan melanjutkan, kamu menyetujui',
    this.center = true,
  });

  final String prefix;
  final bool center;

  void _open(BuildContext context, String title, List<LegalSection> sections) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalPage(title: title, sections: sections),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.caption.copyWith(color: AppColors.textTertiary);
    final link = AppTextStyles.caption.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
    );

    return Wrap(
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$prefix ', style: base),
        InkWell(
          onTap: () => _open(context, 'Syarat & Ketentuan', AccountLegal.terms),
          child: Text('Syarat & Ketentuan', style: link),
        ),
        Text(' dan ', style: base),
        InkWell(
          onTap: () => _open(context, 'Kebijakan Privasi', AccountLegal.privacy),
          child: Text('Kebijakan Privasi', style: link),
        ),
        Text(' FinPay.', style: base),
      ],
    );
  }
}
