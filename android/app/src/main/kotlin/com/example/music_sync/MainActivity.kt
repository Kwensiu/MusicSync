package com.example.music_sync

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val channelName = "music_sync/android_file_access"
    private val runtimeChannelName = "music_sync/android_runtime"
    private val pickDirectoryRequestCode = 44881
    private var pendingDirectoryResult: MethodChannel.Result? = null
    private val readSessions = mutableMapOf<String, InputStream>()
    private val writeSessions = mutableMapOf<String, OutputStream>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickDirectory" -> pickDirectory(result)
                    "listChildren" -> listChildren(call, result)
                    "stat" -> stat(call, result)
                    "createDirectory" -> createDirectory(call, result)
                    "openRead" -> openRead(call, result)
                    "readChunk" -> readChunk(call, result)
                    "closeReadSession" -> closeReadSession(call, result)
                    "openWrite" -> openWrite(call, result)
                    "writeChunk" -> writeChunk(call, result)
                    "closeWriteSession" -> closeWriteSession(call, result)
                    "renameEntry" -> renameEntry(call, result)
                    "deleteEntry" -> deleteEntry(call, result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, runtimeChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setKeepAliveEnabled" -> setKeepAliveEnabled(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun setKeepAliveEnabled(call: MethodCall, result: MethodChannel.Result) {
        try {
            val enabled = call.argument<Boolean>("enabled") ?: false
            if (enabled) {
                ConnectionKeepAliveService.start(this)
            } else {
                ConnectionKeepAliveService.stop(this)
            }
            result.success(null)
        } catch (error: SecurityException) {
            result.error("set_keep_alive_permission_denied", error.message, null)
        } catch (error: Exception) {
            result.error("set_keep_alive_failed", error.message, null)
        }
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingDirectoryResult != null) {
            result.error("busy", "Another directory picker request is active.", null)
            return
        }

        pendingDirectoryResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        startActivityForResult(intent, pickDirectoryRequestCode)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != pickDirectoryRequestCode) {
            return
        }

        val pending = pendingDirectoryResult
        pendingDirectoryResult = null

        if (pending == null) {
            return
        }

        try {
            if (resultCode != Activity.RESULT_OK) {
                pending.success(null)
                return
            }

            val treeUri = data?.data
            if (treeUri == null) {
                pending.success(null)
                return
            }

            val grantedFlags = (data.flags
                and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
            if (grantedFlags != 0) {
                contentResolver.takePersistableUriPermission(treeUri, grantedFlags)
            }

            val documentId = DocumentsContract.getTreeDocumentId(treeUri)
            val handle = hashMapOf<String, Any?>(
                "entryId" to buildEntryId(treeUri, documentId),
                "displayName" to (resolveDisplayName(treeUri, documentId) ?: documentId.substringAfterLast(':'))
            )
            pending.success(handle)
        } catch (error: Exception) {
            pending.error("pick_directory_failed", error.message, null)
        }
    }

    private fun listChildren(call: MethodCall, result: MethodChannel.Result) {
        try {
            val entryId = call.argument<String>("directoryId")
                ?: throw IllegalArgumentException("directoryId is required.")
            val parsed = parseEntryId(entryId)
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                parsed.treeUri,
                parsed.documentId
            )
            val children = mutableListOf<Map<String, Any?>>()

            contentResolver.query(
                childrenUri,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                    DocumentsContract.Document.COLUMN_SIZE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED
                ),
                null,
                null,
                null
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    children.add(cursorToEntry(parsed.treeUri, cursor))
                }
            }

            result.success(children)
        } catch (error: Exception) {
            result.error("list_children_failed", error.message, null)
        }
    }

    private fun stat(call: MethodCall, result: MethodChannel.Result) {
        try {
            val entryId = call.argument<String>("entryId")
                ?: throw IllegalArgumentException("entryId is required.")
            val parsed = parseEntryId(entryId)
            val documentUri = DocumentsContract.buildDocumentUriUsingTree(
                parsed.treeUri,
                parsed.documentId
            )

            contentResolver.query(
                documentUri,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                    DocumentsContract.Document.COLUMN_SIZE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED
                ),
                null,
                null,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    result.success(cursorToEntry(parsed.treeUri, cursor))
                    return
                }
            }

            result.success(null)
        } catch (error: Exception) {
            result.error("stat_failed", error.message, null)
        }
    }

    private fun createDirectory(call: MethodCall, result: MethodChannel.Result) {
        try {
            val parentId = call.argument<String>("parentId")
                ?: throw IllegalArgumentException("parentId is required.")
            val name = call.argument<String>("name")
                ?: throw IllegalArgumentException("name is required.")
            val parsed = parseEntryId(parentId)
            val existing = findChildByName(
                treeUri = parsed.treeUri,
                parentDocumentId = parsed.documentId,
                childName = name
            )
            if (existing != null && existing.mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
                result.success(buildEntryId(parsed.treeUri, existing.documentId))
                return
            }
            val createdUri = DocumentsContract.createDocument(
                contentResolver,
                DocumentsContract.buildDocumentUriUsingTree(parsed.treeUri, parsed.documentId),
                DocumentsContract.Document.MIME_TYPE_DIR,
                name
            ) ?: throw IllegalStateException("Directory creation returned null.")

            result.success(
                buildEntryId(createdUri, DocumentsContract.getDocumentId(createdUri))
            )
        } catch (error: Exception) {
            result.error("create_directory_failed", error.message, null)
        }
    }

    private fun openRead(call: MethodCall, result: MethodChannel.Result) {
        try {
            val entryId = call.argument<String>("entryId")
                ?: throw IllegalArgumentException("entryId is required.")
            val parsed = parseEntryId(entryId)
            val fileUri = DocumentsContract.buildDocumentUriUsingTree(
                parsed.treeUri,
                parsed.documentId
            )
            val stream = contentResolver.openInputStream(fileUri)
                ?: throw IllegalStateException("Unable to open input stream.")
            val sessionId = UUID.randomUUID().toString()
            readSessions[sessionId] = stream
            result.success(sessionId)
        } catch (error: Exception) {
            result.error("open_read_failed", error.message, null)
        }
    }

    private fun readChunk(call: MethodCall, result: MethodChannel.Result) {
        try {
            val sessionId = call.argument<String>("sessionId")
                ?: throw IllegalArgumentException("sessionId is required.")
            val stream = readSessions[sessionId]
                ?: throw IllegalStateException("Read session not found.")
            val buffer = ByteArray(64 * 1024)
            val bytesRead = stream.read(buffer)
            if (bytesRead <= 0) {
                result.success("")
                return
            }
            result.success(
                Base64.encodeToString(buffer.copyOf(bytesRead), Base64.NO_WRAP)
            )
        } catch (error: Exception) {
            result.error("read_chunk_failed", error.message, null)
        }
    }

    private fun closeReadSession(call: MethodCall, result: MethodChannel.Result) {
        try {
            val sessionId = call.argument<String>("sessionId")
                ?: throw IllegalArgumentException("sessionId is required.")
            val stream = readSessions.remove(sessionId)
                ?: throw IllegalStateException("Read session not found.")
            stream.close()
            result.success(null)
        } catch (error: Exception) {
            result.error("close_read_failed", error.message, null)
        }
    }

    private fun openWrite(call: MethodCall, result: MethodChannel.Result) {
        try {
            val parentId = call.argument<String>("parentId")
                ?: throw IllegalArgumentException("parentId is required.")
            val name = call.argument<String>("name")
                ?: throw IllegalArgumentException("name is required.")
            val parsed = parseEntryId(parentId)
            val parentUri = DocumentsContract.buildDocumentUriUsingTree(
                parsed.treeUri,
                parsed.documentId
            )
            val mimeType = mimeTypeFor(name)

            val existing = findChildByName(
                treeUri = parsed.treeUri,
                parentDocumentId = parsed.documentId,
                childName = name
            )
            if (existing != null && existing.mimeType != DocumentsContract.Document.MIME_TYPE_DIR) {
                val existingUri = DocumentsContract.buildDocumentUriUsingTree(
                    parsed.treeUri,
                    existing.documentId
                )
                DocumentsContract.deleteDocument(contentResolver, existingUri)
            }

            val fileUri = DocumentsContract.createDocument(
                contentResolver,
                parentUri,
                mimeType,
                name
            ) ?: throw IllegalStateException("File creation returned null.")

            val stream = contentResolver.openOutputStream(fileUri, "wt")
                ?: throw IllegalStateException("Unable to open output stream.")
            val sessionId = UUID.randomUUID().toString()
            writeSessions[sessionId] = stream
            result.success(sessionId)
        } catch (error: Exception) {
            result.error("open_write_failed", error.message, null)
        }
    }

    private fun writeChunk(call: MethodCall, result: MethodChannel.Result) {
        try {
            val sessionId = call.argument<String>("sessionId")
                ?: throw IllegalArgumentException("sessionId is required.")
            val data = call.argument<String>("data")
                ?: throw IllegalArgumentException("data is required.")
            val stream = writeSessions[sessionId]
                ?: throw IllegalStateException("Write session not found.")
            stream.write(Base64.decode(data, Base64.DEFAULT))
            result.success(null)
        } catch (error: Exception) {
            result.error("write_chunk_failed", error.message, null)
        }
    }

    private fun closeWriteSession(call: MethodCall, result: MethodChannel.Result) {
        try {
            val sessionId = call.argument<String>("sessionId")
                ?: throw IllegalArgumentException("sessionId is required.")
            val stream = writeSessions.remove(sessionId)
                ?: throw IllegalStateException("Write session not found.")
            stream.flush()
            stream.close()
            result.success(null)
        } catch (error: Exception) {
            result.error("close_write_failed", error.message, null)
        }
    }

    private fun renameEntry(call: MethodCall, result: MethodChannel.Result) {
        try {
            val entryId = call.argument<String>("entryId")
                ?: throw IllegalArgumentException("entryId is required.")
            val newName = call.argument<String>("newName")
                ?: throw IllegalArgumentException("newName is required.")
            val parsed = parseEntryId(entryId)
            val documentUri = DocumentsContract.buildDocumentUriUsingTree(
                parsed.treeUri,
                parsed.documentId
            )
            val renamedUri = DocumentsContract.renameDocument(
                contentResolver,
                documentUri,
                newName
            ) ?: throw IllegalStateException("Rename returned null.")
            result.success(
                buildEntryId(parsed.treeUri, DocumentsContract.getDocumentId(renamedUri))
            )
        } catch (error: Exception) {
            result.error("rename_entry_failed", error.message, null)
        }
    }

    private fun deleteEntry(call: MethodCall, result: MethodChannel.Result) {
        try {
            val entryId = call.argument<String>("entryId")
                ?: throw IllegalArgumentException("entryId is required.")
            val parsed = parseEntryId(entryId)
            val documentUri = DocumentsContract.buildDocumentUriUsingTree(
                parsed.treeUri,
                parsed.documentId
            )
            DocumentsContract.deleteDocument(contentResolver, documentUri)
            result.success(null)
        } catch (error: Exception) {
            result.error("delete_entry_failed", error.message, null)
        }
    }

    private fun cursorToEntry(treeUri: Uri, cursor: Cursor): Map<String, Any?> {
        val documentId = cursor.getString(0)
        val displayName = cursor.getString(1) ?: documentId
        val mimeType = cursor.getString(2)
        val size = if (cursor.isNull(3)) 0L else cursor.getLong(3)
        val modifiedTime = if (cursor.isNull(4)) 0L else cursor.getLong(4)

        return mapOf(
            "entryId" to buildEntryId(treeUri, documentId),
            "name" to displayName,
            "isDirectory" to (mimeType == DocumentsContract.Document.MIME_TYPE_DIR),
            "size" to size,
            "modifiedTime" to modifiedTime
        )
    }

    private fun resolveDisplayName(treeUri: Uri, documentId: String): String? {
        val projection = arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
        val documentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId)
        contentResolver.query(documentUri, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getString(0)
            }
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            documentId.substringAfterLast(':')
        } else {
            null
        }
    }

    private fun buildEntryId(treeUri: Uri, documentId: String): String {
        return "${treeUri}|||$documentId"
    }

    private fun mimeTypeFor(name: String): String {
        val extension = name.substringAfterLast('.', "").lowercase()
        return when (extension) {
            "flac" -> "audio/flac"
            "mp3" -> "audio/mpeg"
            "m4a" -> "audio/mp4"
            "wav" -> "audio/wav"
            "aac" -> "audio/aac"
            else -> "application/octet-stream"
        }
    }

    private fun findChildByName(
        treeUri: Uri,
        parentDocumentId: String,
        childName: String
    ): ChildDocumentInfo? {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            parentDocumentId
        )
        contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE
            ),
            null,
            null,
            null
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val documentId = cursor.getString(0)
                val displayName = cursor.getString(1)
                val mimeType = cursor.getString(2)
                if (displayName == childName) {
                    return ChildDocumentInfo(
                        documentId = documentId,
                        mimeType = mimeType
                    )
                }
            }
        }
        return null
    }

    private fun parseEntryId(entryId: String): TreeEntryId {
        val parts = entryId.split("|||", limit = 2)
        require(parts.size == 2) { "Invalid Android entryId." }
        return TreeEntryId(Uri.parse(parts[0]), parts[1])
    }

    private data class TreeEntryId(
        val treeUri: Uri,
        val documentId: String
    )

    private data class ChildDocumentInfo(
        val documentId: String,
        val mimeType: String?
    )
}
