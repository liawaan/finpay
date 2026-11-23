import 'dart:io';
import 'dart:typed_data';

Future<String> saveImageToDevice(String fileName, Uint8List bytes) async {
  try {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return fileName;
  }
}
