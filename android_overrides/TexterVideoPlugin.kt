package __PKG__

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
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
            else -> result.notImplemented()
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
