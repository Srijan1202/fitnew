package me.tryfitos.app

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

/**
 * Beta 3.2 (ADR-027 amendment): the launcher icon is whichever activity-alias
 * (`.IconStandard`, `.IconWhite`, ...) is enabled; the manifest enables only
 * Standard. The phone keeps the choice itself, so nothing is stored in Dart.
 * Whether a premium icon may be chosen is decided in Dart, like the themes.
 */
object AppIcons {
    val NAMES = listOf("standard", "white", "gold", "glow", "lime", "blaze")

    private fun component(context: Context, name: String) =
        ComponentName(context, "me.tryfitos.app.Icon" + name.replaceFirstChar { it.uppercase() })

    private fun enabled(context: Context, name: String): Boolean =
        when (context.packageManager.getComponentEnabledSetting(component(context, name))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            // Never changed: the manifest's own value (only Standard is on).
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> name == "standard"
            else -> false
        }

    fun current(context: Context): String = NAMES.firstOrNull { enabled(context, it) } ?: "standard"

    /**
     * The new alias first, then the others off, so the launcher never sees an
     * app with no entry. DONT_KILL_APP keeps FITOS running, though some
     * launchers still close it once while they redraw.
     */
    fun choose(context: Context, name: String) {
        val pm = context.packageManager
        pm.setComponentEnabledSetting(
            component(context, name),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for (other in NAMES) {
            if (other == name) continue
            pm.setComponentEnabledSetting(
                component(context, other),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
