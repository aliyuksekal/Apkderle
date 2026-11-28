package com.benim.namazasistani

import android.app.Activity
import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import java.io.File

/**
 * Açılış kapısı: uygulama bir önceki açılışta çöktüyse önce hata raporunu
 * gösterir (kullanıcı kopyalayıp geliştiriciye gönderebilir), değilse
 * doğrudan asıl ekrana geçer.
 */
class StartActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val report = try { lastCrashReport() } catch (e: Throwable) { null }
        if (report != null) {
            startActivity(Intent(this, CrashActivity::class.java).putExtra("report", report))
        } else {
            startActivity(Intent(this, MainActivity::class.java).setData(intent?.data))
        }
        finish()
        overridePendingTransition(0, 0)
    }

    private fun lastCrashReport(): String? {
        val prefs = getSharedPreferences("crash_gate", Context.MODE_PRIVATE)
        val seen = prefs.getLong("seen", 0L)
        val sb = StringBuilder()
        var newest = 0L

        // Java çökmesi: App.kt hata metnini dosyaya yazar.
        val f = File(filesDir, "son_hata.txt")
        if (f.exists() && f.lastModified() > seen) {
            sb.append(f.readText()).append("\n\n")
            newest = f.lastModified()
        }

        // Yerel (native) çökmeler ve diğer çıkışlar: Android'in kaydı.
        if (Build.VERSION.SDK_INT >= 30) {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val infos = am.getHistoricalProcessExitReasons(packageName, 0, 5)
            for (i in infos) {
                if (i.timestamp <= seen) continue
                val bad = i.reason == ApplicationExitInfo.REASON_CRASH ||
                    i.reason == ApplicationExitInfo.REASON_CRASH_NATIVE ||
                    i.reason == ApplicationExitInfo.REASON_ANR ||
                    i.reason == ApplicationExitInfo.REASON_INITIALIZATION_FAILURE ||
                    i.reason == ApplicationExitInfo.REASON_SIGNALED
                if (!bad) continue
                newest = maxOf(newest, i.timestamp)
                sb.append("Çıkış nedeni: ${reasonName(i.reason)} (durum ${i.status})\n")
                sb.append("Süreç: ${i.processName}\n")
                sb.append("Açıklama: ${i.description}\n")
                try {
                    i.traceInputStream?.use { s ->
                        val bytes = s.readBytes()
                        // Tombstone ikili olabilir: okunabilir parçaları al.
                        val text = String(bytes, Charsets.ISO_8859_1)
                            .split(Regex("[^\\x20-\\x7E\\n]+"))
                            .filter { it.trim().length >= 6 }
                            .joinToString("\n")
                        sb.append("İz:\n").append(text.take(15000)).append("\n")
                    }
                } catch (_: Throwable) {}
                sb.append("\n")
            }
        }
        if (newest == 0L) return null
        prefs.edit().putLong("seen", newest).apply()
        val header = "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}), " +
            "${Build.MANUFACTURER} ${Build.MODEL}\n\n"
        return header + sb.toString()
    }

    private fun reasonName(r: Int) = when (r) {
        ApplicationExitInfo.REASON_CRASH -> "Java çökmesi"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "Yerel (native) çökme"
        ApplicationExitInfo.REASON_ANR -> "Yanıt vermiyor (ANR)"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "Başlatma hatası"
        ApplicationExitInfo.REASON_SIGNALED -> "Sinyalle sonlandı"
        else -> "Kod $r"
    }
}
