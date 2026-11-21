import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Model data Target Menabung untuk koleksi `saving_goals` di Firebase Firestore (Bagian Tugas Pidi).
class SavingGoalModel {
  const SavingGoalModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.currentAmount,
    required this.targetAmount,
    required this.monthlyDebit,
    required this.eta,
    this.colorHex = 0xFF2563EB,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String category;
  final int currentAmount;
  final int targetAmount;
  final int monthlyDebit;
  final String eta;
  final int colorHex;
  final DateTime? createdAt;

  Color get color => Color(colorHex);

  double get progress =>
      targetAmount <= 0 ? 0.0 : (currentAmount / targetAmount).clamp(0.0, 1.0);

  int get percentage => (progress * 100).round();

  SavingGoalModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? category,
    int? currentAmount,
    int? targetAmount,
    int? monthlyDebit,
    String? eta,
    int? colorHex,
    DateTime? createdAt,
  }) {
    return SavingGoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      category: category ?? this.category,
      currentAmount: currentAmount ?? this.currentAmount,
      targetAmount: targetAmount ?? this.targetAmount,
      monthlyDebit: monthlyDebit ?? this.monthlyDebit,
      eta: eta ?? this.eta,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'category': category,
      'currentAmount': currentAmount,
      'targetAmount': targetAmount,
      'monthlyDebit': monthlyDebit,
      'eta': eta,
      'colorHex': colorHex,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory SavingGoalModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return SavingGoalModel(
      id: (map['id'] as String?) ??
          docId ??
          'goal_${DateTime.now().millisecondsSinceEpoch}',
      userId: (map['userId'] as String?) ?? 'finpay_user_01',
      title: (map['title'] as String?) ?? 'Target Menabung',
      category: (map['category'] as String?) ?? 'Impian',
      currentAmount: (map['currentAmount'] as num?)?.toInt() ?? 0,
      targetAmount: (map['targetAmount'] as num?)?.toInt() ?? 10000000,
      monthlyDebit: (map['monthlyDebit'] as num?)?.toInt() ?? 500000,
      eta: (map['eta'] as String?) ?? 'Desember 2025',
      colorHex: (map['colorHex'] as num?)?.toInt() ?? 0xFF2563EB,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }
}

/// Model data Pinjaman Instan untuk koleksi `loans` di Firebase Firestore (Bagian Tugas Pidi).
class LoanModel {
  const LoanModel({
    required this.id,
    required this.userId,
    required this.principalAmount,
    required this.tenorMonths,
    required this.monthlyInstallment,
    required this.paidMonths,
    required this.referenceNumber,
    this.interestRateMonthly = 0.009,
    this.status = 'Aktif',
    this.createdAt,
  });

  final String id;
  final String userId;
  final int principalAmount;
  final int tenorMonths;
  final int monthlyInstallment;
  final int paidMonths;
  final String referenceNumber;
  final double interestRateMonthly;
  final String status;
  final DateTime? createdAt;

  int get remainingMonths => (tenorMonths - paidMonths).clamp(0, tenorMonths);
  int get remainingBalance => remainingMonths * monthlyInstallment;
  bool get isCompleted => paidMonths >= tenorMonths || status == 'Lunas';

  LoanModel copyWith({
    String? id,
    String? userId,
    int? principalAmount,
    int? tenorMonths,
    int? monthlyInstallment,
    int? paidMonths,
    String? referenceNumber,
    double? interestRateMonthly,
    String? status,
    DateTime? createdAt,
  }) {
    return LoanModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      principalAmount: principalAmount ?? this.principalAmount,
      tenorMonths: tenorMonths ?? this.tenorMonths,
      monthlyInstallment: monthlyInstallment ?? this.monthlyInstallment,
      paidMonths: paidMonths ?? this.paidMonths,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      interestRateMonthly: interestRateMonthly ?? this.interestRateMonthly,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'principalAmount': principalAmount,
      'tenorMonths': tenorMonths,
      'monthlyInstallment': monthlyInstallment,
      'paidMonths': paidMonths,
      'referenceNumber': referenceNumber,
      'interestRateMonthly': interestRateMonthly,
      'status': status,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory LoanModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return LoanModel(
      id: (map['id'] as String?) ??
          docId ??
          'loan_${DateTime.now().millisecondsSinceEpoch}',
      userId: (map['userId'] as String?) ?? 'finpay_user_01',
      principalAmount: (map['principalAmount'] as num?)?.toInt() ?? 5000000,
      tenorMonths: (map['tenorMonths'] as num?)?.toInt() ?? 6,
      monthlyInstallment:
          (map['monthlyInstallment'] as num?)?.toInt() ?? 878333,
      paidMonths: (map['paidMonths'] as num?)?.toInt() ?? 0,
      referenceNumber: (map['referenceNumber'] as String?) ?? 'FPX-LN90123849',
      interestRateMonthly:
          (map['interestRateMonthly'] as num?)?.toDouble() ?? 0.009,
      status: (map['status'] as String?) ?? 'Aktif',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }
}

/// Model data Promo & Voucher untuk koleksi `promos` di Firebase Firestore (Bagian Tugas Pidi).
class PromoModel {
  const PromoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.code,
    required this.category,
    required this.validity,
    required this.discountAmount,
    this.isClaimed = false,
    this.icon = Icons.local_offer_rounded,
    this.color = AppColors.primary,
  });

  final String id;
  final String title;
  final String description;
  final String code;
  final String category;
  final String validity;
  final int discountAmount;
  final bool isClaimed;
  final IconData icon;
  final Color color;

  PromoModel copyWith({
    String? id,
    String? title,
    String? description,
    String? code,
    String? category,
    String? validity,
    int? discountAmount,
    bool? isClaimed,
    IconData? icon,
    Color? color,
  }) {
    return PromoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      code: code ?? this.code,
      category: category ?? this.category,
      validity: validity ?? this.validity,
      discountAmount: discountAmount ?? this.discountAmount,
      isClaimed: isClaimed ?? this.isClaimed,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'code': code,
      'category': category,
      'validity': validity,
      'discountAmount': discountAmount,
      'isClaimed': isClaimed,
    };
  }
}

/// Model ringkasan analisis Arus Kas (Cash Flow) & Skor Kesehatan Finansial (Bagian Tugas Pidi).
class CashFlowSummaryModel {
  const CashFlowSummaryModel({
    required this.period,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalSaving,
    required this.financialHealthScore,
    required this.healthStatusLabel,
    required this.incomeGrowthLabel,
    required this.expenseRatioLabel,
  });

  final String period;
  final int totalIncome;
  final int totalExpense;
  final int totalSaving;
  final int financialHealthScore;
  final String healthStatusLabel;
  final String incomeGrowthLabel;
  final String expenseRatioLabel;

  int get netSurplus => totalIncome - totalExpense;
}

/// Model Pos Anggaran Bulanan (Smart Budgeting).
class BudgetCategoryModel {
  const BudgetCategoryModel({
    required this.id,
    required this.title,
    required this.monthlyLimit,
    required this.spentAmount,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final int monthlyLimit;
  final int spentAmount;
  final IconData icon;
  final Color color;

  double get progress =>
      monthlyLimit <= 0 ? 0.0 : (spentAmount / monthlyLimit).clamp(0.0, 1.0);
  int get percentage => (progress * 100).round();
  int get remaining => (monthlyLimit - spentAmount).clamp(0, monthlyLimit);
  bool get isOverBudget => spentAmount > monthlyLimit;

  BudgetCategoryModel copyWith({
    String? id,
    String? title,
    int? monthlyLimit,
    int? spentAmount,
    IconData? icon,
    Color? color,
  }) {
    return BudgetCategoryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      spentAmount: spentAmount ?? this.spentAmount,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }
}
