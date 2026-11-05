import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';

/// Titik-titik indikator PIN (terisi / kosong / error).
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.length,
    required this.filled,
    this.hasError = false,
  });

  final int length;
  final int filled;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final activeColor = hasError ? AppColors.danger : AppColors.primary;

    return Semantics(
      label: 'PIN terisi $filled dari $length digit',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < filled ? activeColor : Colors.transparent,
                  border: Border.all(
                    color: i < filled ? activeColor : AppColors.border,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Keypad angka 3x4 dengan tombol hapus. Dipakai untuk OTP dan PIN.
/// Ada getaran halus saat tombol ditekan (di HP) dan label aksesibilitas.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Kalau false, semua tombol dimatikan (mis. saat akun terkunci).
  final bool enabled;

  static const List<List<String>> _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '<'],
  ];

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Column(
          children: [
            for (final row in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    for (final key in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs + 2,
                          ),
                          child: _Key(
                            label: key,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (key == '<') {
                                onBackspace();
                              } else {
                                onDigit(key);
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox(height: 56);

    return Semantics(
      button: true,
      label: label == '<' ? 'Hapus' : label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: SizedBox(
            height: 56,
            child: Center(
              child: label == '<'
                  ? const Icon(
                      Icons.backspace_outlined,
                      color: AppColors.textSecondary,
                    )
                  : Text(label, style: AppTextStyles.h1),
            ),
          ),
        ),
      ),
    );
  }
}
