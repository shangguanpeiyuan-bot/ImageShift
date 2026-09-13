package io.github.shangguanpeiyuanbot.imageshift

import android.app.Activity
import android.app.ActivityManager
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private val filesRequest = 6101
    private val treeRequest = 6102
    private val session by lazy { File(cacheDir, "imageshift-${UUID.randomUUID()}").apply { mkdirs() } }
    private val maxFileBytes = 128L * 1024 * 1024
    private var importedBytes = 0L
    private var mediaPicker = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AndroidMediaBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        worker.execute {
            // Only old, app-owned UUID session directories; preserve this
            // session and anything less than 24 hours old (including another window).
            val current = session.canonicalFile
            val cutoff = System.currentTimeMillis() - 24L * 60 * 60 * 1000
            cacheDir.listFiles()?.filter { it.name.matches(Regex("imageshift-[0-9a-fA-F-]{36}")) }?.forEach {
                val target = it.canonicalFile
                if (target.parentFile == cacheDir.canonicalFile && target != current && target.isDirectory && target.lastModified() < cutoff) {
                    target.deleteRecursively()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.shangguanpeiyuanbot.imageshift/files").setMethodCallHandler { call, result ->
            when (call.method) {
                "applicationDirectory" -> result.success(filesDir.absolutePath)
                "availableMemory" -> {
                    val info = ActivityManager.MemoryInfo()
                    getSystemService(ActivityManager::class.java).getMemoryInfo(info)
                    result.success(if (info.lowMemory) 0L else info.availMem)
                }
                "validateOutput" -> execute(result) {
                    val uri = Uri.parse(call.argument<String>("tree")!!)
                    val document = DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
                    contentResolver.query(document, arrayOf(DocumentsContract.Document.COLUMN_FLAGS), null, null, null)?.use {
                        check(it.moveToFirst() && it.getInt(0) and DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE != 0) { "目录权限已失效" }
                    } ?: error("目录权限已失效")
                    null
                }
                "pickImages", "pickMedia", "pickOutput" -> {
                    if (pending != null) { result.error("busy", "文件选择器已打开", null); return@setMethodCallHandler }
                    val isFiles = call.method != "pickOutput"
                    mediaPicker = call.method == "pickMedia"
                    val intent = Intent(if (isFiles) Intent.ACTION_OPEN_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        putExtra(Intent.EXTRA_LOCAL_ONLY, true)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        if (isFiles) {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                        } else {
                            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        }
                    }
                    try {
                        pending = result
                        startActivityForResult(intent, if (isFiles) filesRequest else treeRequest)
                    } catch (error: Exception) {
                        pending = null
                        result.error("picker", "无法打开系统文件选择器", null)
                    }
                }
                "workDirectory" -> result.success(File(session, "output").apply { mkdirs() }.absolutePath)
                "releaseCache" -> execute(result) {
                    val root = session.canonicalFile
                    val outputRoot = File(root, "output")
                    for (path in call.argument<List<String>>("paths") ?: emptyList()) {
                        val file = File(path).canonicalFile
                        // Exactly one private subfolder below this session;
                        // never accept an original path or a document URI.
                        require(file.parentFile?.parentFile == root && file.isFile) { "暂存文件无效" }
                        val size = file.length()
                        check(file.delete()) { "无法清理临时缓存" }
                        if (file.parentFile != outputRoot) importedBytes = (importedBytes - size).coerceAtLeast(0L)
                        if (file.parentFile?.list()?.isEmpty() == true) file.parentFile?.delete()
                    }
                    null
                }
                "publish" -> execute(result) {
                    publish(Uri.parse(call.argument<String>("tree")!!),
                        File(call.argument<String>("path")!!), call.argument<String>("name")!!,
                        call.argument<String>("mime")!!)
                }
                "openOutput" -> {
                    try {
                        val tree = Uri.parse(call.argument<String>("tree")!!)
                        val document = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                        startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(document, DocumentsContract.Document.MIME_TYPE_DIR)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        })
                        result.success(null)
                    } catch (error: Exception) { result.error("open", "此设备没有可打开目录的文件管理器", null) }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun execute(result: MethodChannel.Result, action: () -> Any?) {
        worker.execute {
            try {
                val value = action()
                runOnUiThread { result.success(value) }
            } catch (error: Exception) {
                runOnUiThread { result.error("storage", error.message ?: "文件访问失败，请重新授权目录", null) }
            }
        }
    }

    @Deprecated("System document picker result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != filesRequest && requestCode != treeRequest) return
        val callback = pending ?: return
        val unrestrictedMedia = mediaPicker
        pending = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            callback.success(if (requestCode == filesRequest) emptyList<Any>() else null)
            return
        }
        if (requestCode == treeRequest) {
            val uri = data.data
            if (uri == null) { callback.error("tree", "未取得目录授权", null); return }
            execute(callback) {
                val grant = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                contentResolver.takePersistableUriPermission(uri, grant)
                val doc = DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
                var name = "所选文件夹"
                contentResolver.query(doc, arrayOf(OpenableColumns.DISPLAY_NAME, DocumentsContract.Document.COLUMN_FLAGS), null, null, null)?.use {
                    if (!it.moveToFirst()) error("无法读取所选目录")
                    name = it.getString(0)
                    if (it.getInt(1) and DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE == 0) error("此目录不允许创建文件，请重新选择")
                } ?: error("无法读取所选目录")
                mapOf("uri" to uri.toString(), "name" to name)
            }
            return
        }
        val uris = mutableListOf<Uri>()
        data.clipData?.let { clip -> for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri) }
        if (uris.isEmpty()) data.data?.let { uris.add(it) }
        execute(callback) {
            if (uris.size > 500) error("一次最多选择 500 个文件，请分批处理")
            uris.distinct().map { uri ->
                var name = "图片"
                var copied: File? = null
                try {
                    var knownSize = -1L
                    contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use {
                        if (it.moveToFirst()) { name = it.getString(0) ?: name; if (!it.isNull(1)) knownSize = it.getLong(1) }
                    }
                    if (!unrestrictedMedia && knownSize > maxFileBytes) error("文件超过 128 MiB 上限")
                    if (knownSize > 0 && knownSize > session.usableSpace) error("本地可用空间不足以暂存所选文件")
                    val safeName = name.replace(Regex("[\\\\/:*?\"<>|\\p{Cntrl}]"), "_").take(120).ifBlank { "image" }
                    copied = File(File(session, UUID.randomUUID().toString()).apply { mkdirs() }, safeName)
                    var written = 0L
                    contentResolver.openInputStream(uri)?.use { input ->
                        copied.outputStream().use { output ->
                            val buffer = ByteArray(64 * 1024)
                            while (true) {
                                val count = input.read(buffer)
                                if (count < 0) break
                                written += count
                                if (!unrestrictedMedia && (written > maxFileBytes || importedBytes + written > 2L * 1024 * 1024 * 1024)) error("已达到本次导入缓存上限，请分批处理")
                                output.write(buffer, 0, count)
                            }
                        }
                    } ?: error("无法读取所选文件")
                    importedBytes += written
                    mapOf("path" to copied.absolutePath, "name" to name)
                } catch (error: Exception) {
                    copied?.delete()
                    mapOf("path" to "", "name" to name, "error" to (error.message ?: "读取失败"))
                }
            }
        }
    }

    private fun publish(tree: Uri, input: File, name: String, mime: String): String {
        val outputRoot = File(session, "output").canonicalFile
        require(input.canonicalFile.parentFile == outputRoot && input.isFile) { "输出暂存文件无效" }
        val parentId = DocumentsContract.getTreeDocumentId(tree)
        val parent = DocumentsContract.buildDocumentUriUsingTree(tree, parentId)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        val names = mutableSetOf<String>()
        val ids = mutableSetOf<String>()
        contentResolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            while (it.moveToNext()) { ids.add(it.getString(0)); names.add(it.getString(1).lowercase()) }
        } ?: error("无法检查目录中的重名文件，请重新授权")
        val base = name.substringBeforeLast('.', name)
        val ext = name.substringAfterLast('.', "")
        var candidate = name
        var index = 1
        while (candidate.lowercase() in names) {
            if (index > 9999) error("同名文件过多")
            candidate = "${base}_${index++}.$ext"
        }
        val created = DocumentsContract.createDocument(contentResolver, parent, mime, candidate) ?: error("无法创建输出文件")
        // Reject a misbehaving provider returning an existing document. Never delete it.
        if (DocumentsContract.getDocumentId(created) in ids) error("目录提供程序未创建新文件，已停止保存以保护已有文件")
        try {
            val expected = MessageDigest.getInstance("SHA-256")
            input.inputStream().use { source ->
                contentResolver.openOutputStream(created, "w")?.use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val count = source.read(buffer)
                        if (count < 0) break
                        expected.update(buffer, 0, count)
                        output.write(buffer, 0, count)
                    }
                    output.flush()
                } ?: error("无法写入输出文件")
            }
            val actual = MessageDigest.getInstance("SHA-256")
            contentResolver.openInputStream(created)?.use { source ->
                val buffer = ByteArray(64 * 1024)
                while (true) { val count = source.read(buffer); if (count < 0) break; actual.update(buffer, 0, count) }
            } ?: error("无法校验保存结果")
            check(expected.digest().contentEquals(actual.digest())) { "保存校验失败，请检查剩余空间" }
            return created.toString()
        } catch (error: Exception) {
            try { DocumentsContract.deleteDocument(contentResolver, created) } catch (_: Exception) { }
            throw error
        }
    }

    override fun onDestroy() {
        pending?.error("closed", "文件选择已结束", null)
        pending = null
        worker.shutdown()
        super.onDestroy()
    }
}
