package com.texter.texter

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class ErrorActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val errorText = intent.getStringExtra("error_text") ?: "Unknown crash (no details captured)"

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#1a1a1a"))
            setPadding(32, 80, 32, 32)
        }

        val title = TextView(this).apply {
            text = "App Crashed"
            setTextColor(Color.parseColor("#ff5555"))
            textSize = 22f
            setPadding(0, 0, 0, 24)
        }
        root.addView(title)

        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }

        val copyButton = Button(this).apply {
            text = "Copy Error"
            setOnClickListener {
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("crash_log", errorText))
                text = "Copied!"
            }
        }
        buttonRow.addView(copyButton)

        val closeButton = Button(this).apply {
            text = "Close App"
            setOnClickListener { finishAffinity() }
        }
        buttonRow.addView(closeButton)

        root.addView(buttonRow)

        val scrollView = ScrollView(this)
        val textView = TextView(this).apply {
            text = errorText
            setTextColor(Color.WHITE)
            textSize = 12f
            setTextIsSelectable(true)
            setPadding(0, 32, 0, 0)
        }
        scrollView.addView(textView)
        root.addView(scrollView)

        setContentView(root)
    }
}
