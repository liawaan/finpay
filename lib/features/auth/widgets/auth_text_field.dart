import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';

/// Input teks standar halaman autentikasi: label kecil di atas, kotak putih
/// ringkas dengan border, pesan error di bawah, dan ikon mata untuk kolom
/// sandi.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.prefix,
    this.suffix,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.obscure = false,
    this.readOnly = false,
    this.maxLength,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  /// Widget di kiri dalam kotak input, mis. kode negara "+62".
  final Widget? prefix;

  /// Widget di kanan dalam kotak input (diabaikan kalau [obscure]).
  final Widget? suffix;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  /// Kalau true, teks disamarkan dan muncul tombol lihat/sembunyikan.
  final bool obscure;

  /// Dipakai untuk kolom yang diisi lewat picker (mis. tanggal lahir).
  final bool readOnly;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _hidden = widget.obscure;

  OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: _hidden,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          maxLength: widget.maxLength,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            hintStyle:
                AppTextStyles.body.copyWith(color: AppColors.textTertiary),
            counterText: '',
            errorText: widget.errorText,
            errorMaxLines: 2,
            errorStyle:
                AppTextStyles.caption.copyWith(color: AppColors.danger),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md + 2,
              vertical: AppSpacing.md,
            ),
            prefixIcon: widget.prefix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md + 2),
                    child: widget.prefix,
                  ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Tampilkan' : 'Sembunyikan',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textTertiary,
                      size: AppSizes.iconMd - 2,
                    ),
                  )
                : widget.suffix,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 40, minHeight: 36),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.primary, 1.5),
            errorBorder: _border(AppColors.danger),
            focusedErrorBorder: _border(AppColors.danger, 1.5),
            border: _border(AppColors.border),
          ),
        ),
      ],
    );
  }
}
