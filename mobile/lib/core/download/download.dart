import 'download_io.dart'
    if (dart.library.js_interop) 'download_web.dart'
    as impl;

/// Saves [bytes] as [fileName]: a browser download on the web; on Android
/// the system share sheet with the file ("Save to device", Files, Gallery…).
Future<void> saveFile(List<int> bytes, String fileName, String mimeType) =>
    impl.saveFile(bytes, fileName, mimeType);
