// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

/// Membuka pemilih file gambar di browser lalu men-decode barcode QRIS di dalamnya.
Future<String?> pickAndDecodePlatformQrisImage() async {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()..accept = 'image/*';

  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files.first;
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) async {
      try {
        final dataUrl = reader.result?.toString() ?? '';
        if (dataUrl.isNotEmpty &&
            js_util.hasProperty(html.window, 'finpayDecodeQrImageDataUrl')) {
          final promise = js_util.callMethod<Object>(
            html.window,
            'finpayDecodeQrImageDataUrl',
            [dataUrl],
          );
          final decoded = await js_util.promiseToFuture<Object?>(promise);
          final text = (decoded?.toString() ?? '').trim();
          if (!completer.isCompleted) {
            completer.complete(text.isNotEmpty ? text : '');
          }
          return;
        }
      } catch (_) {}
      if (!completer.isCompleted) completer.complete('');
    });
    reader.readAsDataUrl(file);
  });

  input.click();
  return completer.future.timeout(
    const Duration(seconds: 45),
    onTimeout: () => null,
  );
}
