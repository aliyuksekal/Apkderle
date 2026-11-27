package com.benim.namazasistani

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.PowerManager
import io.flutter.FlutterInjector
import java.io.File

/**
 * Uygulama içindeki (Flutter asset) ses dosyalarını sırayla çalar.
 * Android'in kendi MediaPlayer'ı kullanılır; internet gerekmez.
 * Olaylar: "done" (liste bitti), "error" (çalınamadı).
 */
class AssetAudio(
    private val ctx: Context,
    private val onEvent: (event: String, token: Int, detail: String?) -> Unit,
) {
    private var player: MediaPlayer? = null
    private var files: List<String> = emptyList()
    private var index = -1
    private var token = 0
    private var focus: AudioFocusRequest? = null
    private val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val attrs = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()

    /** Medya ses seviyesi (0 = sessiz). */
    fun mediaVolume(): Int = am.getStreamVolume(AudioManager.STREAM_MUSIC)

    fun play(paths: List<String>, tok: Int) {
        stopInternal(notify = false)
        files = paths
        index = -1
        token = tok
        requestFocus()
        next()
    }

    fun stop() = stopInternal(notify = false)

    private fun next() {
        releasePlayer()
        index++
        if (index >= files.size) {
            abandonFocus()
            onEvent("done", token, null)
            return
        }
        val path = files[index]
        try {
            val mp = MediaPlayer()
            mp.setAudioAttributes(attrs)
            mp.setWakeMode(ctx, PowerManager.PARTIAL_WAKE_LOCK)
            setSource(mp, path)
            mp.setOnCompletionListener { next() }
            mp.setOnErrorListener { _, what, extra ->
                fail("Ses çalınamadı ($what/$extra): $path")
                true
            }
            mp.prepare()
            player = mp
            mp.start()
        } catch (e: Exception) {
            fail("Ses dosyası açılamadı: $path (${e.javaClass.simpleName})")
        }
    }

    private fun setSource(mp: MediaPlayer, path: String) {
        if (path.startsWith("raw:")) {
            val id = ctx.resources.getIdentifier(path.removePrefix("raw:"), "raw", ctx.packageName)
            ctx.resources.openRawResourceFd(id).use { afd ->
                mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            }
            return
        }
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(path)
        try {
            ctx.assets.openFd(key).use { afd ->
                mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            }
        } catch (e: Exception) {
            // Sıkıştırılmış paketlerde openFd çalışmaz: önbelleğe kopyala.
            val out = File(ctx.cacheDir, "audio/" + path.replace('/', '_'))
            if (!out.exists()) {
                out.parentFile?.mkdirs()
                ctx.assets.open(key).use { inp -> out.outputStream().use { inp.copyTo(it) } }
            }
            mp.setDataSource(out.absolutePath)
        }
    }

    private fun fail(msg: String) {
        val t = token
        releasePlayer()
        files = emptyList()
        abandonFocus()
        onEvent("error", t, msg)
    }

    private fun stopInternal(notify: Boolean) {
        val t = token
        files = emptyList()
        releasePlayer()
        abandonFocus()
        if (notify) onEvent("done", t, null)
    }

    private fun releasePlayer() {
        player?.let {
            try { it.stop() } catch (_: Exception) {}
            it.release()
        }
        player = null
    }

    private fun requestFocus() {
        if (Build.VERSION.SDK_INT >= 26) {
            val r = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attrs)
                .build()
            focus = r
            am.requestAudioFocus(r)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }
    }

    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= 26) {
            focus?.let { am.abandonAudioFocusRequest(it) }
            focus = null
        } else {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(null)
        }
    }

    fun release() = stopInternal(notify = false)
}
