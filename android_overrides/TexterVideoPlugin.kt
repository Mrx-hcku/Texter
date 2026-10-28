package __PKG__

import android.annotation.TargetApi
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.os.Handler
import android.os.Looper
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

/**
 * Shrinks a video before it is uploaded (like WhatsApp / Telegram):
 * longest side limited to [maxSide] px, H.264 + AAC, lower bitrate.
 * Returns the new file's path, or null if compression was not possible /
 * not worth it — the app then simply sends the original.
 */
class __CLASS__ : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private val main = Handler(Looper.getMainLooper())
    private val jobs = HashMap<String, Transformer>()
    private val pending = HashMap<String, Result>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "texter/video")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "compress" -> compress(call, result)
            "cancel" -> {
                val id = call.argument<String>("jobId")
                main.post {
                    if (id != null) {
                        val t = jobs.remove(id)
                        try {
                            t?.cancel()
                        } catch (e: Throwable) {
                        }
                        pending.remove(id)?.success(null)
                    }
                    result.success(null)
                }
            }
            "saveToGallery" -> result.success(
                saveToGallery(call.argument<String>("path"), call.argument<String>("name"), call.argument<String>("mime"))
            )
            "shareText" -> result.success(shareText(call.argument<String>("text")))
            else -> result.notImplemented()
        }
    }

    /** Copies a downloaded photo / video into the phone Gallery (Pictures/Texter, Movies/Texter). Android 10+. */
    private fun saveToGallery(path: String?, name: String?, mime: String?): Boolean {
        val ctx = context ?: return false
        if (path == null || name == null || mime == null) return false
        if (Build.VERSION.SDK_INT < 29) return false
        return try {
            saveQ(ctx, path, name, mime)
        } catch (e: Throwable) {
            false
        }
    }

    @TargetApi(29)
    private fun saveQ(ctx: Context, path: String, name: String, mime: String): Boolean {
        val isVideo = mime.startsWith("video")
        val values = ContentValues()
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, name)
        values.put(MediaStore.MediaColumns.MIME_TYPE, mime)
        val dir = if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES
        values.put(MediaStore.MediaColumns.RELATIVE_PATH, dir + "/Texter")
        values.put(MediaStore.MediaColumns.IS_PENDING, 1)
        val collection = if (isVideo) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
        val resolver = ctx.contentResolver
        val uri = resolver.insert(collection, values) ?: return false
        val out = resolver.openOutputStream(uri) ?: return false
        out.use { o -> File(path).inputStream().use { it.copyTo(o) } }
        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return true
    }

    private fun shareText(text: String?): Boolean {
        val ctx = context ?: return false
        if (text == null) return false
        return try {
            val send = Intent(Intent.ACTION_SEND)
            send.type = "text/plain"
            send.putExtra(Intent.EXTRA_TEXT, text)
            val chooser = Intent.createChooser(send, null)
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(chooser)
            true
        } catch (e: Throwable) {
            false
        }
    }

    private fun finish(jobId: String, value: String?) {
        jobs.remove(jobId)
        pending.remove(jobId)?.success(value)
    }

    private fun compress(call: MethodCall, result: Result) {
        val ctx = context
        val input = call.argument<String>("input")
        val jobId = call.argument<String>("jobId") ?: input
        val maxSide = call.argument<Int>("maxSide") ?: 1280
        if (ctx == null || input == null || jobId == null) {
            result.success(null)
            return
        }
        val inFile = File(input)
        if (!inFile.exists()) {
            result.success(null)
            return
        }
        val outFile = File(ctx.cacheDir, "vc_" + System.currentTimeMillis() + ".mp4")

        // Work out the size the video will have on screen (rotation aware).
        var w = 0
        var h = 0
        var rot = 0
        try {
            val r = MediaMetadataRetriever()
            r.setDataSource(input)
            w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            r.release()
        } catch (e: Throwable) {
        }
        val rotated = rot == 90 || rot == 270
        val dw = if (rotated) h else w
        val dh = if (rotated) w else h
        val longest = maxOf(dw, dh)
        var targetH = dh
        var resize = false
        if (longest > maxSide && dh > 0) {
            targetH = (dh * maxSide.toFloat() / longest).toInt()
            targetH -= targetH % 2
            resize = targetH > 0
        }
        val shortSide = minOf(dw, dh)
        val bitrate = if (shortSide >= 700 || shortSide == 0) 2_000_000 else 1_200_000

        pending[jobId] = result
        main.post {
            try {
                val effects: List<Effect> =
                    if (resize) listOf(Presentation.createForHeight(targetH)) else emptyList()
                val edited = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(inFile)))
                    .setEffects(Effects(emptyList(), effects))
                    .build()
                val encoder = DefaultEncoderFactory.Builder(ctx)
                    .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(bitrate).build())
                    .build()
                val transformer = Transformer.Builder(ctx)
                    .setVideoMimeType(MimeTypes.VIDEO_H264)
                    .setAudioMimeType(MimeTypes.AUDIO_AAC)
                    .setEncoderFactory(encoder)
                    .addListener(object : Transformer.Listener {
                        override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                            // Only use the result if it is really smaller.
                            if (outFile.exists() && outFile.length() > 0 && outFile.length() < inFile.length()) {
                                finish(jobId, outFile.absolutePath)
                            } else {
                                outFile.delete()
                                finish(jobId, null)
                            }
                        }

                        override fun onError(
                            composition: Composition,
                            exportResult: ExportResult,
                            exportException: ExportException
                        ) {
                            outFile.delete()
                            finish(jobId, null)
                        }
                    })
                    .build()
                jobs[jobId] = transformer
                transformer.start(edited, outFile.absolutePath)
            } catch (t: Throwable) {
                outFile.delete()
                finish(jobId, null)
            }
        }
    }
}
