package tm.modahouse.app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tm.modahouse.app/gallery")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveMedia") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name") ?: "modahouse.jpg"
                val mime = call.argument<String>("mimeType") ?: "image/jpeg"
                // Before Android 10 writing to shared storage needs a permission:
                // the Dart side then falls back to the share sheet.
                if (bytes == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                Thread {
                    val ok = saveMedia(bytes, name, mime)
                    runOnUiThread { result.success(ok) }
                }.start()
            }
    }

    /** Inserts the file into MediaStore (Pictures/ModaHouse or Movies/ModaHouse). */
    private fun saveMedia(bytes: ByteArray, name: String, mime: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val video = mime.startsWith("video/")
        val collection = if (video) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
        val dir = if (video) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, "$dir/ModaHouse")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = applicationContext.contentResolver
        val uri = resolver.insert(collection, values) ?: return false
        return try {
            val stream = resolver.openOutputStream(uri)
                ?: throw IllegalStateException("no output stream")
            stream.use { it.write(bytes) }
            val done = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            resolver.update(uri, done, null, null)
            true
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            false
        }
    }
}
