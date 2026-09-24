package com.texter.texter

import android.app.Application
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MyApplication : Application() {

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        setupCrashHandler()
        writeMarker("attachBaseContext")
    }

    override fun onCreate() {
        try {
            writeMarker("Application.onCreate STARTED")
            super.onCreate()
            writeMarker("Application.onCreate COMPLETED")
        } catch (t: Throwable) {
            handleCrash(t)
        }
    }

    private fun setupCrashHandler() {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                handleCrash(throwable)
            } catch (e: Exception) {
            }
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }

    private fun handleCrash(throwable: Throwable) {
        writeCrashLog(throwable)
        try {
            val sw = StringWriter()
            throwable.printStackTrace(PrintWriter(sw))
            val intent = Intent(applicationContext, ErrorActivity::class.java).apply {
                putExtra("error_text", sw.toString())
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            applicationContext.startActivity(intent)
        } catch (e: Exception) {
        }
    }

    private fun writeMarker(msg: String) {
        val ts = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US).format(Date())
        writeToFile("\n[$ts] $msg\n")
    }

    private fun writeCrashLog(t: Throwable) {
        val sw = StringWriter()
        t.printStackTrace(PrintWriter(sw))
        val ts = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US).format(Date())
        writeToFile("\n===== CRASH at $ts =====\n$sw\n")
    }

    private fun writeToFile(text: String) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = applicationContext.contentResolver
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, "texter_crash_log.txt")
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
                logFile.appendText(text)
                return
            }
        } catch (e: Exception) {
        }
        try {
            val fallbackDir = getExternalFilesDir(null) ?: filesDir
            File(fallbackDir, "crash_log.txt").appendText(text)
        } catch (e: Exception) {
        }
    }
}
