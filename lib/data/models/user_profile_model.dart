/// Model data profil pengguna untuk koleksi `users` di Firebase Firestore (Bagian Tugas Pidi).
class UserProfileModel {
  const UserProfileModel({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.password = 'password123',
    this.address = 'Jl. Melati No. 12, Jakarta Selatan',
    this.nik = '3174 •••• •••• 0001',
    this.birthDate = '14 Agustus 2001',
    this.membership = 'FinPay Premier',
    this.finPoin = 1420,
    this.memberSince = 'Jan 2024',
    this.referralCode = 'FINPAY-REZA25',
    this.referralBonus = 500,
    this.pin = '123456',
    this.kycStatus = 'Menunggu Verifikasi',
    this.dailyLimit = 25000000,
    this.maxDailyLimit = 50000000,
    this.biometricEnabled = false,
    this.notificationEnabled = true,
    this.language = 'Indonesia',
    this.virtualCardFrozen = false,
    this.virtualCardOnlineEnabled = true,
    this.updatedAt,
  });

  final String userId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String password;
  final String address;
  final String nik;
  final String birthDate;
  final String membership;
  final int finPoin;
  final String memberSince;
  final String referralCode;
  final int referralBonus;
  final String pin;
  final String kycStatus;
  final int dailyLimit;
  final int maxDailyLimit;
  final bool biometricEnabled;
  final bool notificationEnabled;
  final String language;
  final bool virtualCardFrozen;
  final bool virtualCardOnlineEnabled;
  final DateTime? updatedAt;

  static String resolveMembershipTier(int points) {
    if (points >= 2000) return 'FinPay Elite';
    if (points >= 1000) return 'FinPay Premier';
    return 'FinPay Reguler';
  }

  bool get isKycVerified => kycStatus.toLowerCase() == 'terverifikasi';

  /// Skor keamanan akun (0–100): PIN aktif (30) + KYC (30) + Biometrik (25) + Notifikasi (15).
  int get securityScore =>
      30 +
      (isKycVerified ? 30 : 10) +
      (biometricEnabled ? 25 : 0) +
      (notificationEnabled ? 15 : 0);

  UserProfileModel copyWith({
    String? userId,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? password,
    String? address,
    String? nik,
    String? birthDate,
    String? membership,
    int? finPoin,
    String? memberSince,
    String? referralCode,
    int? referralBonus,
    String? pin,
    String? kycStatus,
    int? dailyLimit,
    int? maxDailyLimit,
    bool? biometricEnabled,
    bool? notificationEnabled,
    String? language,
    bool? virtualCardFrozen,
    bool? virtualCardOnlineEnabled,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      password: password ?? this.password,
      address: address ?? this.address,
      nik: nik ?? this.nik,
      birthDate: birthDate ?? this.birthDate,
      membership: membership ?? this.membership,
      finPoin: finPoin ?? this.finPoin,
      memberSince: memberSince ?? this.memberSince,
      referralCode: referralCode ?? this.referralCode,
      referralBonus: referralBonus ?? this.referralBonus,
      pin: pin ?? this.pin,
      kycStatus: kycStatus ?? this.kycStatus,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      maxDailyLimit: maxDailyLimit ?? this.maxDailyLimit,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      language: language ?? this.language,
      virtualCardFrozen: virtualCardFrozen ?? this.virtualCardFrozen,
      virtualCardOnlineEnabled:
          virtualCardOnlineEnabled ?? this.virtualCardOnlineEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'password': password,
      'address': address,
      'nik': nik,
      'birthDate': birthDate,
      'membership': membership,
      'finPoin': finPoin,
      'memberSince': memberSince,
      'referralCode': referralCode,
      'referralBonus': referralBonus,
      'pin': pin,
      'kycStatus': kycStatus,
      'dailyLimit': dailyLimit,
      'maxDailyLimit': maxDailyLimit,
      'biometricEnabled': biometricEnabled,
      'notificationEnabled': notificationEnabled,
      'language': language,
      'virtualCardFrozen': virtualCardFrozen,
      'virtualCardOnlineEnabled': virtualCardOnlineEnabled,
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory UserProfileModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return UserProfileModel(
      userId: (map['userId'] as String?) ?? docId ?? 'finpay_user_01',
      fullName: (map['fullName'] as String?) ?? 'Reza Pratama',
      email: (map['email'] as String?) ?? 'reza.pratama@email.com',
      phoneNumber: (map['phoneNumber'] as String?) ?? '0812-3456-7890',
      password: (map['password'] as String?) ?? 'password123',
      address: (map['address'] as String?) ??
          'Jl. Melati No. 12, Jakarta Selatan',
      nik: (map['nik'] as String?) ?? '3174 •••• •••• 0001',
      birthDate: (map['birthDate'] as String?) ?? '14 Agustus 2001',
      membership: (map['membership'] as String?) ?? 'FinPay Premier',
      finPoin: (map['finPoin'] as num?)?.toInt() ?? 1420,
      memberSince: (map['memberSince'] as String?) ?? 'Jan 2024',
      referralCode: (map['referralCode'] as String?) ?? 'FINPAY-REZA25',
      referralBonus: (map['referralBonus'] as num?)?.toInt() ?? 500,
      pin: (map['pin'] as String?) ?? '123456',
      kycStatus: (map['kycStatus'] as String?) ?? 'Menunggu Verifikasi',
      dailyLimit: (map['dailyLimit'] as num?)?.toInt() ?? 25000000,
      maxDailyLimit: (map['maxDailyLimit'] as num?)?.toInt() ?? 50000000,
      biometricEnabled: (map['biometricEnabled'] as bool?) ?? false,
      notificationEnabled: (map['notificationEnabled'] as bool?) ?? true,
      language: (map['language'] as String?) ?? 'Indonesia',
      virtualCardFrozen: (map['virtualCardFrozen'] as bool?) ?? false,
      virtualCardOnlineEnabled:
          (map['virtualCardOnlineEnabled'] as bool?) ?? true,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }
}
