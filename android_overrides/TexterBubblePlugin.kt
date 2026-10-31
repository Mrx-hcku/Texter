package __PKG__

import android.annotation.TargetApi
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.content.Context
import android.content.Intent
import android.content.LocusId
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Turns an already-posted message notification into a real Android
 * "Bubble" notification (the Bubble button, like Telegram), with the chat
 * partner's profile picture. Works from the main app and from the FCM
 * background isolate, because it is a normal Flutter plugin.
 * Needs Android 11+ (API 30); on older versions it does nothing.
 */
class __CLASS__ : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "texter/bubble")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "dismissFcm") {
            val c = context
            if (c != null) {
                // Firebase itself posts a plain notification when a push carries a "notification" block.
                // We show our own, so remove Firebase's copy (it can appear a moment later — try a few times).
                for (delayMs in longArrayOf(0L, 400L, 1200L, 3000L)) {
                    handler.postDelayed({ cancelFcmNotifications(c) }, delayMs)
                }
            }
            result.success(true)
            return
        }
        if (call.method == "isSupported") {
            result.success(Build.VERSION.SDK_INT >= 30)
            return
        }
        if (call.method != "attach") {
            result.notImplemented()
            return
        }
        val ctx = context
        val id = call.argument<Int>("id")
        val chatId = call.argument<String>("chatId")
        if (ctx == null || id == null || chatId == null || Build.VERSION.SDK_INT < 30) {
            result.success(false)
            return
        }
        val kind = call.argument<String>("kind") ?: "direct"
        val chatName = call.argument<String>("chatName") ?: ""
        val senderName = call.argument<String>("senderName") ?: ""
        val body = call.argument<String>("body") ?: ""
        val messages = call.argument<List<*>>("messages") ?: emptyList<Any>()
        val avatarPath = call.argument<String>("avatarPath")
        attach(ctx.applicationContext, id, chatId, kind, chatName, senderName, body, messages, avatarPath, 0)
        result.success(true)
    }

    private fun cancelFcmNotifications(ctx: Context) {
        try {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            for (sbn in nm.activeNotifications) {
                val tag = sbn.tag
                if (tag != null && tag.startsWith("FCM-Notification")) nm.cancel(tag, sbn.id)
            }
        } catch (t: Throwable) {
        }
    }

    @TargetApi(30)
    private fun attach(
        ctx: Context,
        id: Int,
        chatId: String,
        kind: String,
        chatName: String,
        senderName: String,
        body: String,
        messages: List<*>,
        avatarPath: String?,
        tries: Int
    ) {
        try {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val sbn = nm.activeNotifications.firstOrNull { it.id == id }
            if (sbn == null) {
                // flutter_local_notifications posts asynchronously — wait a little.
                if (tries < 8) {
                    handler.postDelayed({ attach(ctx, id, chatId, kind, chatName, senderName, body, messages, avatarPath, tries + 1) }, 250)
                }
                return
            }
            val original = sbn.notification
            val text: CharSequence = if (body.isNotEmpty()) body
                else (original.extras.getCharSequence(Notification.EXTRA_TEXT) ?: "")
            val label = if (chatName.isNotEmpty()) chatName
                else if (senderName.isNotEmpty()) senderName else "Chat"
            val personName = if (senderName.isNotEmpty()) senderName else label

            val icon = Icon.createWithBitmap(loadAvatar(avatarPath, label))
            val person = Person.Builder()
                .setName(personName)
                .setKey(chatId)
                .setIcon(icon)
                .setImportant(true)
                .build()

            val pkg = ctx.packageName
            val viewUri = Uri.parse("texter://chat").buildUpon()
                .appendQueryParameter("chatId", chatId)
                .appendQueryParameter("kind", kind)
                .appendQueryParameter("chatName", chatName)
                .build()

            // Sharing shortcut — Android only shows a bubble for a "conversation"
            // that has a published, long-lived shortcut.
            val shortcutId = "chat_$chatId"
            val shortcutIntent = Intent(Intent.ACTION_VIEW, viewUri)
                .setClassName(pkg, "com.texter.texter.MainActivity")
            val shortcut = ShortcutInfo.Builder(ctx, shortcutId)
                .setShortLabel(label)
                .setLongLived(true)
                .setIcon(icon)
                .setIntent(shortcutIntent)
                .setPerson(person)
                .setLocusId(LocusId(shortcutId))
                .setCategories(setOf("android.shortcut.conversation"))
                .build()
            ctx.getSystemService(ShortcutManager::class.java).pushDynamicShortcut(shortcut)

            // What opens inside the bubble: the app, straight into this chat.
            val bubbleIntent = Intent(Intent.ACTION_VIEW, viewUri)
                .setClassName(pkg, "com.texter.texter.BubbleActivity")
            var piFlags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 31) piFlags = piFlags or PendingIntent.FLAG_MUTABLE
            val bubblePi = PendingIntent.getActivity(ctx, chatId.hashCode(), bubbleIntent, piFlags)
            @Suppress("DEPRECATION")
            val bubbleMeta = Notification.BubbleMetadata.Builder(bubblePi, icon)
                .setDesiredHeight(600)
                .build()

            // The style's "user" is the phone's owner; the chat partner is the sender.
            val me = Person.Builder().setName("You").build()
            val style = Notification.MessagingStyle(me)
            if (kind == "group") {
                style.setConversationTitle(label)
                style.setGroupConversation(true)
            }
            // Whole recent history (like WhatsApp), oldest first.
            val people = HashMap<String, Person>()
            var added = 0
            for (item in messages) {
                val m = item as? Map<*, *> ?: continue
                val mText = (m["text"] as? String) ?: continue
                val mTime = (m["time"] as? Number)?.toLong() ?: sbn.postTime
                val mSender = (m["sender"] as? String) ?: ""
                val who = if (kind == "group" && mSender.isNotEmpty()) {
                    people.getOrPut(mSender) {
                        Person.Builder().setName(mSender).setKey("$chatId:$mSender").build()
                    }
                } else person
                style.addMessage(mText, mTime, who)
                added++
            }
            if (added == 0) style.addMessage(text, sbn.postTime, person)

            // Rebuild the SAME notification (keeps Reply / Mark as read buttons,
            // grouping, tap action) and add the bubble parts to it.
            val rebuilt = Notification.Builder.recoverBuilder(ctx, original)
                .setStyle(style)
                .setShortcutId(shortcutId)
                .setLocusId(LocusId(shortcutId))
                .setBubbleMetadata(bubbleMeta)
                .setCategory(Notification.CATEGORY_MESSAGE)
                .setLargeIcon(icon)
                .setOnlyAlertOnce(true)
                .build()
            nm.notify(sbn.tag, id, rebuilt)
        } catch (t: Throwable) {
            // Bubble is a bonus — never break the normal notification.
        }
    }

    /** Round profile picture, or a coloured circle with the first letter. */
    private fun loadAvatar(path: String?, name: String): Bitmap {
        val size = 192
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        var src: Bitmap? = null
        if (!path.isNullOrEmpty()) {
            try {
                src = BitmapFactory.decodeFile(path)
            } catch (t: Throwable) {
                src = null
            }
        }
        if (src != null) {
            val side = minOf(src.width, src.height)
            val sx = (src.width - side) / 2
            val sy = (src.height - side) / 2
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
            canvas.drawBitmap(src, Rect(sx, sy, sx + side, sy + side), Rect(0, 0, size, size), paint)
        } else {
            val bg = Paint(Paint.ANTI_ALIAS_FLAG)
            bg.color = Color.parseColor("#00BFA5")
            canvas.drawCircle(size / 2f, size / 2f, size / 2f, bg)
            val tp = Paint(Paint.ANTI_ALIAS_FLAG)
            tp.color = Color.BLACK
            tp.textSize = size * 0.5f
            tp.textAlign = Paint.Align.CENTER
            tp.isFakeBoldText = true
            val letter = if (name.isNotEmpty()) name.substring(0, 1).uppercase() else "?"
            val y = size / 2f - (tp.descent() + tp.ascent()) / 2f
            canvas.drawText(letter, size / 2f, y, tp)
        }
        return out
    }
}
