package com.benim.namazasistani

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

/** Çökme raporu ekranı (Flutter'dan bağımsız, ayrı süreçte çalışır). */
class CrashActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val report = intent.getStringExtra("report") ?: "Rapor yok"
        val pad = (16 * resources.displayMetrics.density).toInt()
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad * 2, pad, pad)
            setBackgroundColor(Color.parseColor("#FBF3E1"))
        }
        root.addView(TextView(this).apply {
            text = "Uygulama bir hatayla kapandı.\nAşağıdaki \"Kopyala\" düğmesine basıp metni geliştiriciye gönderin."
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            setTextColor(Color.parseColor("#13241D"))
        })
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        row.addView(Button(this).apply {
            text = "Kopyala"
            setOnClickListener {
                val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                cm.setPrimaryClip(ClipData.newPlainText("hata", report))
                Toast.makeText(this@CrashActivity, "Kopyalandı", Toast.LENGTH_SHORT).show()
            }
        })
        row.addView(Button(this).apply {
            text = "Paylaş"
            setOnClickListener {
                startActivity(Intent.createChooser(
                    Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, report),
                    "Hata raporunu gönder"
                ))
            }
        })
        row.addView(Button(this).apply {
            text = "Tekrar Aç"
            setOnClickListener {
                startActivity(Intent(this@CrashActivity, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
                finish()
            }
        })
        root.addView(row)
        root.addView(ScrollView(this).apply {
            addView(TextView(this@CrashActivity).apply {
                text = report
                setTextIsSelectable(true)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                setTextColor(Color.parseColor("#13241D"))
            })
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        setContentView(root)
    }
}
