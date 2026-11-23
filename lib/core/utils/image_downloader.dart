import 'dart:typed_data';

import 'image_downloader_stub.dart'
    if (dart.library.html) 'image_downloader_web.dart'
    if (dart.library.io) 'image_downloader_io.dart' as platform_downloader;

/// Menyimpan atau mengunduh byte gambar PNG struk transaksi secara lintas platform.
Future<String> saveReceiptImageToDevice(String fileName, Uint8List bytes) {
  return platform_downloader.saveImageToDevice(fileName, bytes);
}
