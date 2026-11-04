import 'package:finpay/data/dummy/dummy_data.dart';
import 'package:finpay/data/models/transaction_model.dart';
import 'package:finpay/data/services/transaction_service.dart';
import 'package:finpay/data/services/wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int initialCash;
  late int initialSaving;

  setUp(() {
    // Nonaktifkan panggilan jaringan Firestore saat unit test
    FirebaseFirestoreConfig.projectId = '';
    initialCash = DummyData.cashBalance;
    initialSaving = DummyData.savingBalance;
  });

  tearDown(() {
    DummyData.cashBalance = initialCash;
    DummyData.savingBalance = initialSaving;
    DummyData.totalBalance = initialCash + initialSaving;
    FirebaseFirestoreConfig.projectId = 'finpay-app-4026a';
  });

  group('WalletService action sheets backend', () {
    test('depositToSaving memindahkan saldo cash ke tabungan dan mencatat transaksi', () async {
      final trx = await WalletService.instance.depositToSaving(
        amount: 250000,
        goalTitle: 'Liburan ke Jepang',
        timeFormatted: '19:30',
      );

      expect(DummyData.cashBalance, initialCash - 250000);
      expect(DummyData.savingBalance, initialSaving + 250000);
      expect(trx.type, TransactionType.saving);
      expect(trx.referenceNumber, startsWith('FPX-SV'));
    });

    test('disburseLoan mencairkan dana ke saldo cash dan menghitung cicilan', () async {
      final res = await WalletService.instance.disburseLoan(
        amount: 6000000,
        tenorMonths: 6,
        timeFormatted: '19:35',
      );

      expect(DummyData.cashBalance, initialCash + 6000000);
      expect(res.transaction.type, TransactionType.income);
      expect(res.transaction.referenceNumber, startsWith('FPX-LN'));
      expect(res.monthlyInstallment, greaterThan(1000000));
    });

    test('transferMoney memotong saldo cash dan mencatat referensi FPX', () async {
      final trx = await WalletService.instance.transferMoney(
        recipient: '0812-9988-7766 (Budi)',
        amount: 150000,
        isBankTransfer: false,
        timeFormatted: '19:40',
        note: 'Patungan',
      );

      expect(DummyData.cashBalance, initialCash - 150000);
      expect(trx.type, TransactionType.expense);
      expect(trx.amount, -150000);
    });

    test('createCashoutCode memotong saldo cash dan mengembalikan tokenCode', () async {
      final res = await WalletService.instance.createCashoutCode(
        amount: 200000,
        channelName: 'Indomaret',
        timeFormatted: '19:45',
      );

      expect(DummyData.cashBalance, initialCash - 200000);
      expect(res['tokenCode'], isNotNull);
      expect(res['referenceNumber'], startsWith('FPX-'));
    });
  });
}
