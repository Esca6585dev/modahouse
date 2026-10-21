import 'download_io.dart'
    if (dart.library.js_interop) 'download_web.dart'
    as impl;

/// Saves [bytes] as [fileName]: a browser download on the web. On Android 10+
/// the file goes straight to the gallery (Pictures/ModaHouse or
/// Movies/ModaHouse via MediaStore, no storage permission needed); on older
/// Android, or when that fails, the system share sheet opens with the file
/// ("Save to device", Files, Gallery…).
Future<void> saveFile(List<int> bytes, String fileName, String mimeType) =>
    impl.saveFile(bytes, fileName, mimeType);
