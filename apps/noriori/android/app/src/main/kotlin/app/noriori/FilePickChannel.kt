package app.noriori

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/// 가져올 파일 하나를 고른다. 고른 순간에 읽고 권한을 남기지 않는다.
class FilePickChannel(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private companion object {
        const val PICK_REQUEST = 4202
    }

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, "app.noriori/file_pick").setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "pick") return result.notImplemented()
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*") // 받은 CSV의 형식이 기기마다 octet-stream이나 text로 갈린다
        activity.startActivityForResult(intent, PICK_REQUEST)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_REQUEST) return
        val result = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) return result.success(null)
        worker.execute {
            try {
                val bytes = activity.contentResolver.openInputStream(uri)!!.use { it.readBytes() }
                val picked = mapOf("name" to displayName(uri), "bytes" to bytes)
                main.post { result.success(picked) }
            } catch (error: Throwable) { // 너무 큰 파일의 메모리 부족도 여기로 온다
                main.post { result.error("file_pick", error.message, null) }
            }
        }
    }

    private fun displayName(uri: Uri): String {
        val columns = arrayOf(OpenableColumns.DISPLAY_NAME)
        activity.contentResolver.query(uri, columns, null, null, null)?.use {
            if (it.moveToFirst()) return it.getString(0)
        }
        return uri.lastPathSegment ?: ""
    }
}
