package com.benim.namazasistani

import android.app.Application
import android.content.Intent
import android.os.Build
import android.os.Process
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import kotlin.system.exitProcess

/**
 * Uygulama çökerse hatayı kaydedip ayrı bir ekranda gösterir; kullanıcı
 * metni kopyalayıp geliştiriciye gönderebilir.
 */
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, e ->
            try {
                val sw = StringWriter()
                e.printStackTrace(PrintWriter(sw))
                val pkg = packageManager.getPackageInfo(packageName, 0)
                @Suppress("DEPRECATION")
                val code = if (Build.VERSION.SDK_INT >= 28) pkg.longVersionCode else pkg.versionCode.toLong()
                val report = buildString {
                    append("Namaz Asistanı ${pkg.versionName} ($code)\n")
                    append("Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}), ")
                    append("${Build.MANUFACTURER} ${Build.MODEL}\n")
                    append("İş parçacığı: ${thread.name}\n\n")
                    append(sw.toString().take(12000))
                }
                File(filesDir, "son_hata.txt").writeText(report)
                startActivity(
                    Intent(this, CrashActivity::class.java)
                        .putExtra("report", report)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                )
            } catch (_: Throwable) {
                previous?.uncaughtException(thread, e)
            }
            Process.killProcess(Process.myPid())
            exitProcess(10)
        }
    }
}
