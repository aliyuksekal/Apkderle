package com.benim.namazasistani

import android.content.Context
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
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
    private var pending: Req? = null
    private var appliedVoice: String? = null

    private data class Req(val text: String, val rate: Float, val pitch: Float, val voice: String, val token: Int)
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
        pending?.let { pending = null; speak(it.text, it.rate, it.pitch, it.voice, it.token) }
    }

    private fun turkishVoices(): List<Voice> = try {
        (tts.voices ?: emptySet())
            .filter { it.locale.language == "tr" }
            .sortedWith(compareBy({ it.isNetworkConnectionRequired }, { it.name }))
    } catch (_: Exception) { emptyList() }

    /** Sesin erkek olup olmadığına dair tahmin (motorlar bunu her zaman söylemez). */
    private fun maleGuess(v: Voice): Boolean? {
        val n = v.name.lowercase()
        val f = v.features?.joinToString(" ")?.lowercase() ?: ""
        return when {
            "female" in n || "female" in f || Regex("smtf\\d").containsMatchIn(n) -> false
            "male" in n || "male" in f || Regex("smtm\\d").containsMatchIn(n) -> true
            else -> null
        }
    }

    fun voices(): List<Map<String, Any?>> {
        if (!ready) return emptyList()
        return turkishVoices().map {
            mapOf("name" to it.name, "male" to maleGuess(it), "network" to it.isNetworkConnectionRequired)
        }
    }

    private fun applyVoice(name: String) {
        val list = turkishVoices()
        val v = if (name.isNotEmpty()) list.firstOrNull { it.name == name }
                else list.firstOrNull { maleGuess(it) == true && !it.isNetworkConnectionRequired }
        val key = v?.name ?: ""
        if (key == appliedVoice) return
        appliedVoice = key
        if (v != null) try { tts.voice = v } catch (_: Exception) {}
        else tts.setLanguage(Locale("tr", "TR"))
    }

    fun status(): Map<String, Boolean> = mapOf("ready" to ready, "turkish" to turkish)

    /** false: konuşma motoru yok (çağıran süreye göre devam eder). */
    fun speak(text: String, rate: Float, pitch: Float, voice: String, token: Int): Boolean {
        if (!initialized) {
            pending = Req(text, rate, pitch, voice, token)
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
        applyVoice(voice)
        tts.setSpeechRate(rate)
        tts.setPitch(pitch)
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
