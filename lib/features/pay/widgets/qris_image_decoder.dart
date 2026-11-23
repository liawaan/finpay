import 'qris_image_decoder_stub.dart'
    if (dart.library.html) 'qris_image_decoder_web.dart';

/// Memilih gambar QRIS dari perangkat dan membaca string payload EMVCo QRIS di dalamnya.
Future<String?> pickAndDecodeQrisImage() => pickAndDecodePlatformQrisImage();
