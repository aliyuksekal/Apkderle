package com.benim.namazasistani

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.Surface
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null
    private var tone: ToneGenerator? = null
    private var declination = 0f
    private var audio: AssetAudio? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        channel = MethodChannel(messenger, "namaz/native").also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasVibrator" -> result.success(vibrator().hasVibrator())
                    "vibrate" -> {
                        val pattern = (call.argument<List<Number>>("pattern") ?: emptyList())
                            .map { it.toLong() }.toLongArray()
                        vibrate(pattern, call.argument<Boolean>("strong") ?: false)
                        result.success(null)
                    }
                    "audioPlay" -> {
                        val files = call.argument<List<String>>("files") ?: emptyList()
                        val token = call.argument<Int>("token") ?: 0
                        audioPlayer().play(files, token)
                        result.success(audioPlayer().mediaVolume())
                    }
                    "audioStop" -> {
                        audio?.stop()
                        result.success(null)
                    }
                    "mediaVolume" -> result.success(audioPlayer().mediaVolume())
                    "tone" -> {
                        playTone(call.argument<String>("kind") ?: "tap")
                        result.success(null)
                    }
                    "startGuideService" -> {
                        GuideService.start(this, call.argument<String>("title") ?: "Namaz rehberi")
                        result.success(null)
                    }
                    "updateGuideService" -> {
                        GuideService.update(this, call.argument<String>("text") ?: "")
                        result.success(null)
                    }
                    "stopGuideService" -> {
                        GuideService.stop(this)
                        result.success(null)
                    }
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 41)
                        }
                        result.success(null)
                    }
                    "keepScreenOn" -> {
                        if (call.argument<Boolean>("on") == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    "setCompassLocation" -> {
                        val lat = call.argument<Double>("lat") ?: 0.0
                        val lng = call.argument<Double>("lng") ?: 0.0
                        declination = GeomagneticField(
                            lat.toFloat(), lng.toFloat(), 0f, System.currentTimeMillis()
                        ).declination
                        result.success(null)
                    }
                    "shareText" -> {
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, call.argument<String>("text") ?: "")
                        }
                        startActivity(Intent.createChooser(send, "Paylaş"))
                        result.success(null)
                    }
                    "openBatterySettings" -> {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                        } catch (_: Exception) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.fromParts("package", packageName, null)
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                        }
                        result.success(null)
                    }
                    "openAppSettings" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null)
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Bildirimdeki "Durdur" → Flutter
        GuideService.onStopRequested = {
            Handler(Looper.getMainLooper()).post {
                channel?.invokeMethod("guideStopRequested", null)
            }
        }

        EventChannel(messenger, "namaz/compass").setStreamHandler(CompassHandler())
    }

    private fun audioPlayer(): AssetAudio = audio ?: AssetAudio(applicationContext) { ev, tok, detail ->
        Handler(Looper.getMainLooper()).post {
            channel?.invokeMethod("audioEvent", mapOf("event" to ev, "token" to tok, "detail" to detail))
        }
    }.also { audio = it }

    override fun onDestroy() {
        audio?.release()
        audio = null
        tone?.release()
        tone = null
        GuideService.onStopRequested = null
        super.onDestroy()
    }

    // --- Titreşim

    private fun vibrator(): Vibrator =
        if (Build.VERSION.SDK_INT >= 31) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

    private fun vibrate(pattern: LongArray, strong: Boolean) {
        if (pattern.isEmpty()) return
        val v = vibrator()
        if (!v.hasVibrator()) return
        val effect = VibrationEffect.createWaveform(pattern, -1)
        if (strong) {
            // Ekran kapalıyken/arka planda da hissedilsin diye alarm kullanımı.
            if (Build.VERSION.SDK_INT >= 33) {
                v.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM))
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(
                    effect,
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build()
                )
            }
        } else {
            v.vibrate(effect)
        }
    }

    // --- Kısa sesler (gerçek dinî ses değildir; yalnızca geri bildirim bip'i)

    private fun playTone(kind: String) {
        try {
            val g = tone ?: ToneGenerator(AudioManager.STREAM_MUSIC, 70).also { tone = it }
            when (kind) {
                "goal" -> g.startTone(ToneGenerator.TONE_PROP_ACK, 400)
                "test" -> g.startTone(ToneGenerator.TONE_PROP_BEEP2, 500)
                else -> g.startTone(ToneGenerator.TONE_PROP_BEEP, 40)
            }
        } catch (_: RuntimeException) {
            // Ses kanalı alınamadı; sessizce geç.
        }
    }

    // --- Pusula

    private inner class CompassHandler : EventChannel.StreamHandler, SensorEventListener {
        private var sink: EventChannel.EventSink? = null
        private var sm: SensorManager? = null
        private var accuracy = SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM
        private var lastSent = 0L
        private var smoothed: Double? = null
        private val rot = FloatArray(9)
        private val orient = FloatArray(3)
        private var legacy = false
        private var gravity: FloatArray? = null
        private var geomag: FloatArray? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            sink = events
            val m = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            sm = m
            val s = m.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
                ?: m.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
            val mag = m.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
            val acc = m.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            if (s == null && (mag == null || acc == null)) {
                events.error("no_sensor", "Pusula algılayıcısı yok", null)
                return
            }
            // Döndürme vektörü yoksa ivmeölçer + manyetometre ile hesapla.
            legacy = s == null
            if (s != null) m.registerListener(this, s, SensorManager.SENSOR_DELAY_UI)
            mag?.let { m.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) }
            if (legacy) acc?.let { m.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) }
        }

        override fun onCancel(arguments: Any?) {
            sm?.unregisterListener(this)
            sink = null
            smoothed = null
        }

        override fun onAccuracyChanged(sensor: Sensor?, acc: Int) {
            if (sensor?.type == Sensor.TYPE_MAGNETIC_FIELD) accuracy = acc
        }

        override fun onSensorChanged(e: SensorEvent) {
            if (e.sensor.type == Sensor.TYPE_MAGNETIC_FIELD) {
                accuracy = e.accuracy
                if (!legacy) return
                geomag = e.values.clone()
            } else if (e.sensor.type == Sensor.TYPE_ACCELEROMETER) {
                gravity = e.values.clone()
            }
            if (legacy) {
                val g = gravity ?: return
                val mg = geomag ?: return
                if (!SensorManager.getRotationMatrix(rot, null, g, mg)) return
            } else {
                SensorManager.getRotationMatrixFromVector(rot, e.values)
            }
            SensorManager.getOrientation(rot, orient)
            var deg = Math.toDegrees(orient[0].toDouble())
            val rotation = if (Build.VERSION.SDK_INT >= 30) display?.rotation ?: 0
            else @Suppress("DEPRECATION") windowManager.defaultDisplay.rotation
            deg += when (rotation) {
                Surface.ROTATION_90 -> 90.0
                Surface.ROTATION_180 -> 180.0
                Surface.ROTATION_270 -> 270.0
                else -> 0.0
            }
            deg = (deg + declination + 720.0) % 360.0
            // Yumuşatma (açı sarmalamasını dikkate alarak)
            val prev = smoothed
            smoothed = if (prev == null) deg else {
                var d = deg - prev
                if (d > 180) d -= 360
                if (d < -180) d += 360
                (prev + d * 0.2 + 360.0) % 360.0
            }
            val now = System.currentTimeMillis()
            if (now - lastSent < 60) return
            lastSent = now
            sink?.success(mapOf("heading" to smoothed, "accuracy" to accuracy))
        }
    }
}
