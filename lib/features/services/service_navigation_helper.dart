import 'package:flutter/material.dart';

import 'cash_flow_page.dart';
import 'promos_page.dart';
import 'savings_page.dart';
import 'top_up_page.dart';
import 'transfer_page.dart';

/// Helper navigasi penuh (Full Page Navigation) dengan animasi transisi halaman yang halus.
abstract class ServiceNavigationHelper {
  static void openService(BuildContext context, String serviceLabel, {VoidCallback? onStateChanged}) {
    final lower = serviceLabel.toLowerCase();

    Widget page;
    if (lower.contains('isi saldo') || lower.contains('top up')) {
      page = const TopUpPage();
    } else if (lower.contains('kirim') || lower.contains('transfer')) {
      page = const TransferPage();
    } else if (lower.contains('menabung') || lower.contains('tabungan') || lower.contains('setor')) {
      page = const SavingsPage();
    } else if (lower.contains('cash flow') || lower.contains('arus kas')) {
      page = const CashFlowPage();
    } else if (lower.contains('promo')) {
      page = const PromosPage();
    } else {
      page = const TopUpPage();
    }

    Navigator.push(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.08, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);
          final fadeAnimation = CurvedAnimation(parent: animation, curve: Curves.easeIn);

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    ).then((_) {
      onStateChanged?.call();
    });
  }
}
