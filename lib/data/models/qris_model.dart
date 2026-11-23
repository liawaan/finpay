/// Error ketika string QRIS tidak valid (format, checksum, atau field wajib).
class QrisFormatException implements Exception {
  const QrisFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Perhitungan checksum CRC16/CCITT-FALSE (poly 0x1021, init 0xFFFF)
/// sesuai standar EMVCo QR Code yang dipakai QRIS Bank Indonesia.
abstract final class QrisCrc {
  static String crc16(String data) {
    var crc = 0xFFFF;
    for (final unit in data.codeUnits) {
      crc ^= (unit & 0xFF) << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
        crc &= 0xFFFF;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}

/// Payload QRIS berformat EMVCo Merchant-Presented Mode (TLV).
///
/// Mendukung dua jenis QR:
/// - **Statis** (`01 = 11`): tanpa nominal, pembayar mengisi nominal sendiri.
/// - **Dinamis** (`01 = 12`): nominal sudah terkunci di dalam QR.
///
/// Catatan: ini adalah simulasi QRIS untuk kebutuhan pembelajaran, bukan
/// kode yang terdaftar resmi di ASPI / Bank Indonesia.
class QrisPayload {
  const QrisPayload({
    required this.merchantName,
    required this.merchantCity,
    required this.nmid,
    this.acquirer = 'ID.CO.FINPAY.WWW',
    this.merchantPan = '936000000000000000',
    this.merchantCategoryCode = '5812',
    this.postalCode = '10220',
    this.amount,
    this.referenceLabel,
    this.terminalLabel,
  });

  static const String qrisDomain = 'ID.CO.QRIS.WWW';
  static const String currencyIdr = '360';
  static const String countryId = 'ID';

  final String merchantName;
  final String merchantCity;

  /// National Merchant ID (NMID) yang diterbitkan ASPI.
  final String nmid;
  final String acquirer;
  final String merchantPan;
  final String merchantCategoryCode;
  final String postalCode;

  /// Nominal tetap (hanya untuk QRIS dinamis). `null` = QRIS statis.
  final int? amount;
  final String? referenceLabel;
  final String? terminalLabel;

  bool get isDynamic => amount != null && amount! > 0;

  /// Menandakan apakah QRIS ini milik pengguna personal FinPay (Transfer Antar Pengguna).
  bool get isFinPayUser =>
      terminalLabel == 'FINPAYUSER' ||
      (referenceLabel != null && referenceLabel!.startsWith('FPUSER:'));

  /// Mengambil `userId` pemilik QRIS jika QRIS ini adalah milik pengguna FinPay.
  String? get recipientUserId {
    if (referenceLabel != null && referenceLabel!.startsWith('FPUSER:')) {
      final uid = referenceLabel!.substring('FPUSER:'.length).trim();
      return uid.isNotEmpty ? uid : null;
    }
    return null;
  }

  QrisPayload copyWith({
    int? amount,
    bool clearAmount = false,
    String? referenceLabel,
    String? terminalLabel,
  }) {
    return QrisPayload(
      merchantName: merchantName,
      merchantCity: merchantCity,
      nmid: nmid,
      acquirer: acquirer,
      merchantPan: merchantPan,
      merchantCategoryCode: merchantCategoryCode,
      postalCode: postalCode,
      amount: clearAmount ? null : (amount ?? this.amount),
      referenceLabel: referenceLabel ?? this.referenceLabel,
      terminalLabel: terminalLabel ?? this.terminalLabel,
    );
  }

  static String _tlv(String tag, String value) {
    if (value.length > 99) {
      throw QrisFormatException('Nilai tag $tag terlalu panjang (maks 99).');
    }
    return '$tag${value.length.toString().padLeft(2, '0')}$value';
  }

  /// Menghasilkan string QRIS lengkap beserta checksum CRC16.
  String encode() {
    final buffer = StringBuffer()
      ..write(_tlv('00', '01'))
      ..write(_tlv('01', isDynamic ? '12' : '11'))
      ..write(_tlv(
        '26',
        _tlv('00', acquirer) + _tlv('01', merchantPan) + _tlv('02', nmid),
      ))
      ..write(_tlv(
        '51',
        _tlv('00', qrisDomain) + _tlv('02', nmid) + _tlv('03', 'UMI'),
      ))
      ..write(_tlv('52', merchantCategoryCode))
      ..write(_tlv('53', currencyIdr));

    if (isDynamic) buffer.write(_tlv('54', amount.toString()));

    buffer
      ..write(_tlv('58', countryId))
      ..write(_tlv('59', _truncate(merchantName, 25)))
      ..write(_tlv('60', _truncate(merchantCity, 15)))
      ..write(_tlv('61', postalCode));

    final additional = StringBuffer();
    if (referenceLabel != null && referenceLabel!.isNotEmpty) {
      additional.write(_tlv('05', _truncate(referenceLabel!, 25)));
    }
    if (terminalLabel != null && terminalLabel!.isNotEmpty) {
      additional.write(_tlv('07', _truncate(terminalLabel!, 16)));
    }
    if (additional.isNotEmpty) buffer.write(_tlv('62', additional.toString()));

    // CRC dihitung atas seluruh data termasuk "6304".
    buffer.write('6304');
    final body = buffer.toString();
    return '$body${QrisCrc.crc16(body)}';
  }

  /// Membaca & memvalidasi string QRIS. Melempar [QrisFormatException]
  /// bila format, checksum, mata uang, atau negara tidak sesuai.
  factory QrisPayload.parse(String raw) {
    var data = raw.trim().replaceAll(RegExp(r'\s+'), '');
    // Jika pengguna menempelkan teks yang memiliki awalan sebelum '000201', ambil mulai dari '000201'.
    final startIdx = data.indexOf('000201');
    if (startIdx > 0) {
      data = data.substring(startIdx);
    }
    if (data.length < 24 || !data.startsWith('000201')) {
      throw const QrisFormatException(
        'QR bukan format QRIS yang valid.',
      );
    }

    final crcTagIndex = data.length - 8;
    if (data.substring(crcTagIndex, crcTagIndex + 4) != '6304') {
      throw const QrisFormatException('QRIS tidak memiliki checksum (CRC).');
    }

    final expected = QrisCrc.crc16(data.substring(0, crcTagIndex + 4));
    final actual = data.substring(crcTagIndex + 4).toUpperCase();
    if (expected != actual) {
      throw const QrisFormatException(
        'Checksum QRIS tidak cocok, kode mungkin rusak atau dimodifikasi.',
      );
    }

    final tlv = _readTlv(data.substring(0, crcTagIndex));

    if (tlv['53'] != currencyIdr) {
      throw const QrisFormatException('QRIS hanya mendukung mata uang IDR.');
    }
    if (tlv['58'] != countryId) {
      throw const QrisFormatException('QRIS hanya berlaku untuk Indonesia.');
    }

    final name = tlv['59'];
    if (name == null || name.isEmpty) {
      throw const QrisFormatException('Nama merchant tidak ditemukan.');
    }

    final acquirerInfo =
        tlv['26'] != null ? _readTlv(tlv['26']!) : <String, String>{};
    final nationalInfo =
        tlv['51'] != null ? _readTlv(tlv['51']!) : <String, String>{};
    final additional =
        tlv['62'] != null ? _readTlv(tlv['62']!) : <String, String>{};

    final nmid = nationalInfo['02'] ?? acquirerInfo['02'] ?? '';
    if (nmid.isEmpty) {
      throw const QrisFormatException('NMID merchant tidak ditemukan.');
    }

    int? parsedAmount;
    if (tlv['01'] == '12' && tlv['54'] != null) {
      parsedAmount = double.tryParse(tlv['54']!)?.round();
    }

    return QrisPayload(
      merchantName: name,
      merchantCity: tlv['60'] ?? '',
      nmid: nmid,
      acquirer: acquirerInfo['00'] ?? '',
      merchantPan: acquirerInfo['01'] ?? '',
      merchantCategoryCode: tlv['52'] ?? '0000',
      postalCode: tlv['61'] ?? '',
      amount: parsedAmount,
      referenceLabel: additional['05'],
      terminalLabel: additional['07'],
    );
  }

  static Map<String, String> _readTlv(String data) {
    final result = <String, String>{};
    var index = 0;
    while (index < data.length) {
      if (index + 4 > data.length) {
        throw const QrisFormatException('Struktur data QRIS tidak lengkap.');
      }
      final tag = data.substring(index, index + 2);
      final length = int.tryParse(data.substring(index + 2, index + 4));
      if (length == null) {
        throw const QrisFormatException('Panjang data QRIS tidak valid.');
      }
      final end = index + 4 + length;
      if (end > data.length) {
        throw const QrisFormatException('Struktur data QRIS terpotong.');
      }
      result[tag] = data.substring(index + 4, end);
      index = end;
    }
    return result;
  }

  static String _truncate(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
