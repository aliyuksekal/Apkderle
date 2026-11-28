package com.benim.namazasistani

import android.content.Context
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale

/**
 * Telefonun kendi konuşma motoruyla (Text-to-Speech) Türkçe sesli okuma.
 * Türkçe ses paketi telefonda yüklüyse internet gerekmez.
 * Olay: onDone(token) — okuma bitti ya da durduruldu.
 */
class Speaker(
    ctx: Context,
    private val onDone: (token: Int) -> Unit,
) {
    private var ready = false
    private var initialized = false
    private var turkish = false
    private var pending: Triple<String, Float, Int>? = null
    private var current = -1

    private lateinit var tts: TextToSpeech

    init {
        tts = TextToSpeech(ctx.applicationContext) { status -> onInit(status) }
    }

    private fun onInit(status: Int) {
        initialized = true
        ready = status == TextToSpeech.SUCCESS
        if (ready) {
            val r = tts.setLanguage(Locale("tr", "TR"))
            turkish = r != TextToSpeech.LANG_MISSING_DATA && r != TextToSpeech.LANG_NOT_SUPPORTED
            tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(id: String?) {}
                override fun onDone(id: String?) { id?.toIntOrNull()?.let(onDone) }
                @Deprecated("eski")
                override fun onError(id: String?) { id?.toIntOrNull()?.let(onDone) }
                override fun onError(id: String?, code: Int) { id?.toIntOrNull()?.let(onDone) }
                override fun onStop(id: String?, interrupted: Boolean) { id?.toIntOrNull()?.let(onDone) }
            })
        }
        pending?.let { (t, r, k) -> pending = null; speak(t, r, k) }
    }

    fun status(): Map<String, Boolean> = mapOf("ready" to ready, "turkish" to turkish)

    /** false: konuşma motoru yok (çağıran süreye göre devam eder). */
    fun speak(text: String, rate: Float, token: Int): Boolean {
        if (!initialized) {
            pending = Triple(text, rate, token)
            return true
        }
        if (!ready) {
            onDone(token)
            return false
        }
        if (!turkish) {
            onDone(token)
            return false
        }
        current = token
        tts.setSpeechRate(rate)
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), token.toString())
        return true
    }

    fun stop() {
        pending = null
        if (ready) tts.stop()
    }

    fun release() {
        tts.stop()
        tts.shutdown()
    }
}
