package com.texter.texter

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

open class MainActivity : FlutterActivity() {

    protected open fun isBubbleActivity(): Boolean = false

    private var chatChannel: MethodChannel? = null
    private var pendingChat: HashMap<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        setupCrashHandler()
        try {
            super.onCreate(savedInstanceState)
            if (savedInstanceState == null) pendingChat = parseChatIntent(intent)
        } catch (throwable: Throwable) {
            writeCrashLog(throwable)
            throw throwable
        }
    }

    private fun setupCrashHandler() {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                writeCrashLog(throwable)
            } catch (e: Exception) {
            }
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }

    private fun writeCrashLog(throwable: Throwable) {
        val sw = StringWriter()
        throwable.printStackTrace(PrintWriter(sw))
        val timestamp = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US).format(Date())
        writeToFile("===== CRASH at $timestamp =====\n$sw\n")
    }

    private fun writeToFile(text: String) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = applicationContext.contentResolver
                val displayName = "texter_crash_log.txt"

                // Purani copies (texter_crash_log.txt, (1).txt, (2).txt, ...) delete karo
                // taaki sirf ek hi, latest file rahe.
                resolver.delete(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    "${MediaStore.Downloads.DISPLAY_NAME} = ?",
                    arrayOf(displayName)
                )

                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, displayName)
                    put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                if (uri != null) {
                    resolver.openOutputStream(uri)?.use { it.write(text.toByteArray()) }
                    values.clear()
                    values.put(MediaStore.Downloads.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)
                    return
                }
            } else {
                val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                val logFile = File(downloadsDir, "texter_crash_log.txt")
                logFile.writeText(text)
                return
            }
        } catch (e: Exception) {
        }
        try {
            val fallbackDir = getExternalFilesDir(null) ?: filesDir
            File(fallbackDir, "crash_log.txt").writeText(text)
        } catch (e: Exception) {
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        try {
            super.configureFlutterEngine(flutterEngine)
        } catch (throwable: Throwable) {
            writeCrashLog(throwable)
            throw throwable
        }
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "texter/chat_intent")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingChat" -> {
                    result.success(pendingChat)
                    pendingChat = null
                }
                "isBubble" -> result.success(isBubbleActivity())
                "bringToFront" -> {
                    val i = Intent(this, MainActivity::class.java)
                    i.addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    )
                    startActivity(i)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        chatChannel = channel
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val chat = parseChatIntent(intent) ?: return
        val channel = chatChannel
        if (channel != null) channel.invokeMethod("openChat", chat) else pendingChat = chat
    }

    // texter://chat?chatId=..&kind=..&chatName=..  (sent when the floating bubble is tapped)
    private fun parseChatIntent(intent: Intent?): HashMap<String, String>? {
        val uri = intent?.data ?: return null
        if (uri.scheme != "texter" || uri.host != "chat") return null
        val chatId = uri.getQueryParameter("chatId") ?: return null
        return hashMapOf(
            "chatId" to chatId,
            "kind" to (uri.getQueryParameter("kind") ?: "direct"),
            "chatName" to (uri.getQueryParameter("chatName") ?: "")
        )
    }
}
