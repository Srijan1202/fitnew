package com.example.fitos

import android.app.Activity
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Health Connect opens this when the user asks why FITOS wants their data
 * (`ACTION_SHOW_PERMISSIONS_RATIONALE` on Android 13 and below, the
 * permission-usage alias on 14+). Plain text, read only, no tracking.
 */
class HealthPermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val pad = (24 * resources.displayMetrics.density).toInt()
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad * 2, pad, pad)
            gravity = Gravity.TOP
        }
        layout.addView(
            TextView(this).apply {
                text = "Why FITOS reads your health data"
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
                setPadding(0, 0, 0, pad / 2)
            },
        )
        layout.addView(
            TextView(this).apply {
                text = "FITOS uses your activity, recovery and body data to make its daily " +
                    "recommendations more useful: how much you have moved, how you slept, and " +
                    "your latest weight sit next to your training plan on the Home screen.\n\n" +
                    "FITOS only reads. It never writes to Health Connect, never sends this data " +
                    "to its servers or to any AI service, and never includes it in analytics or " +
                    "crash reports. Data stays on this phone and is cleared when you sign out.\n\n" +
                    "You choose which categories to share, and you can revoke any of them in " +
                    "Health Connect at any time — FITOS keeps working without them."
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            },
        )
        setContentView(layout)
    }
}
