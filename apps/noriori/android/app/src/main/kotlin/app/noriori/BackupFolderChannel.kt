package app.noriori

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/// 사용자가 고른 백업 폴더 (ARCHITECTURE §3.7). 저장소 접근 프레임워크로 읽고 쓴다.
/// 앱 폴더 밖이라 앱을 지워도 남는다. 재설치하면 권한이 사라져 폴더를 다시 고른다.
class BackupFolderChannel(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private companion object {
        const val PICK_REQUEST = 4201
        const val TEMP_PREFIX = "noriori-"
        const val TEMP_SUFFIX = ".tmp"
    }

    private val prefs = activity.getSharedPreferences("backup_folder", Context.MODE_PRIVATE)
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, "app.noriori/backup_folder").setMethodCallHandler(this)
    }

    private val tree: Uri? get() = prefs.getString("tree", null)?.let(Uri::parse)

    private fun granted(uri: Uri) =
        activity.contentResolver.persistedUriPermissions.any { it.uri == uri && it.isWritePermission }

    private fun label(uri: Uri): String =
        DocumentsContract.getTreeDocumentId(uri).substringAfterLast(':').ifEmpty { "/" }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(
                tree?.let { mapOf("name" to label(it), "granted" to granted(it)) },
            )
            "pick" -> {
                // 선택 창이 이미 떠 있으면 앞 요청을 잃지 않게 새 요청을 취소로 답한다
                if (pending != null) return result.success(null)
                pending = result
                activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), PICK_REQUEST)
            }
            "names" -> background(result) {
                children().filter { !it.directory && it.name.endsWith(".json") }.map { it.name }
            }
            "read" -> background(result) {
                try {
                    find(call.argument("name")!!)?.let { doc ->
                        activity.contentResolver.openInputStream(doc)?.use { it.readBytes() }
                    }
                } catch (_: Exception) {
                    null // 구름 자리표시자도 여기로 온다. 읽지 못한 파일로 다룬다
                }
            }
            "write" -> background(result) {
                write(call.argument("name")!!, call.argument("bytes")!!)
                null
            }
            "delete" -> background(result) {
                find(call.argument("name")!!)?.let {
                    DocumentsContract.deleteDocument(activity.contentResolver, it)
                }
                null
            }
            "beginTask", "endTask", "excludeFromBackup" -> result.success(null)
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_REQUEST) return
        val result = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) return result.success(null)
        // 앱 전용 폴더는 앱을 지우면 함께 사라진다
        val insideApp = DocumentsContract.getTreeDocumentId(uri).contains(activity.packageName)
        if (!insideApp) {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            tree?.takeIf { it != uri }?.let(::release)
            prefs.edit().putString("tree", uri.toString()).commit()
        }
        result.success(mapOf("name" to label(uri), "insideApp" to insideApp))
    }

    private fun release(uri: Uri) {
        try {
            activity.contentResolver.releasePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            // 이미 잃은 권한이다
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("backup_folder", e.toString(), null) }
            }
        }
    }

    private data class Child(val id: String, val name: String, val directory: Boolean)

    private fun children(): List<Child> {
        val root = tree ?: return emptyList()
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(
            root,
            DocumentsContract.getTreeDocumentId(root),
        )
        val columns = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE,
        )
        val found = ArrayList<Child>()
        activity.contentResolver.query(uri, columns, null, null, null)?.use {
            while (it.moveToNext()) {
                found.add(Child(it.getString(0), it.getString(1), it.getString(2) == Document.MIME_TYPE_DIR))
            }
        }
        return found
    }

    private fun documentUri(id: String) = DocumentsContract.buildDocumentUriUsingTree(tree!!, id)

    private fun find(name: String): Uri? =
        children().firstOrNull { it.name == name }?.let { documentUri(it.id) }

    /// 임시 이름으로 쓰고 바꾼다. 쓰는 도중에 죽어도 회전이 영영 지우지 못하는 조각이 남지 않는다.
    private fun write(name: String, bytes: ByteArray) {
        val resolver = activity.contentResolver
        val root = tree!!
        val parent = DocumentsContract.buildDocumentUriUsingTree(
            root,
            DocumentsContract.getTreeDocumentId(root),
        )
        for (child in children()) {
            // 사용자가 고른 폴더다. 다른 앱의 임시 파일은 건드리지 않는다
            if (child.name.startsWith(TEMP_PREFIX) && child.name.endsWith(TEMP_SUFFIX)) {
                DocumentsContract.deleteDocument(resolver, documentUri(child.id))
            }
        }
        val temp = DocumentsContract.createDocument(
            resolver,
            parent,
            "application/octet-stream",
            name + TEMP_SUFFIX,
        ) ?: throw IllegalStateException("파일을 만들지 못했다")
        resolver.openOutputStream(temp, "wt")!!.use { it.write(bytes) }
        val renamed = try {
            DocumentsContract.renameDocument(resolver, temp, name)
        } catch (_: UnsupportedOperationException) {
            null
        }
        if (renamed != null) return
        // 이름을 바꾸지 못하는 저장소. 조각이 남을 수 있지만 읽지 못한 파일로 다뤄진다
        DocumentsContract.deleteDocument(resolver, temp)
        val direct = DocumentsContract.createDocument(resolver, parent, "application/json", name)
            ?: throw IllegalStateException("파일을 만들지 못했다")
        resolver.openOutputStream(direct, "wt")!!.use { it.write(bytes) }
    }
}
