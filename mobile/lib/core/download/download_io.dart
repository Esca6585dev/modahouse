import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<void> saveFile(List<int> bytes, String fileName, String mimeType) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: fileName,
          mimeType: mimeType,
        ),
      ],
      fileNameOverrides: [fileName],
    ),
  );
}
