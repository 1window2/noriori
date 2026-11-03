package app.noriori

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var backupFolder: BackupFolderChannel? = null
    private var filePick: FilePickChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backupFolder = BackupFolderChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        filePick = FilePickChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    @Deprecated("Flutter의 활동 결과 경로를 그대로 쓴다")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        backupFolder?.onActivityResult(requestCode, resultCode, data)
        filePick?.onActivityResult(requestCode, resultCode, data)
    }
}
