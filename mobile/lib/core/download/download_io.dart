import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Native side: `MainActivity.kt` (MediaStore insert, Android 10+).
const _gallery = MethodChannel('tm.modahouse.app/gallery');

Future<void> saveFile(List<int> bytes, String fileName, String mimeType) async {
  final data = Uint8List.fromList(bytes);
  if (Platform.isAndroid && await _saveToGallery(data, fileName, mimeType)) {
    return;
  }
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(data, name: fileName, mimeType: mimeType)],
      fileNameOverrides: [fileName],
    ),
  );
}

Future<bool> _saveToGallery(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  try {
    final ok = await _gallery.invokeMethod<bool>('saveMedia', {
      'bytes': bytes,
      'name': fileName,
      'mimeType': mimeType,
    });
    return ok ?? false;
  } catch (_) {
    return false; // Old Android or no channel: fall back to the share sheet.
  }
}
