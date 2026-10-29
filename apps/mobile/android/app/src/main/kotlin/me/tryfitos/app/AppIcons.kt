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
    // Beta 4.2: finisher and fortyTwo, the running badges' icons.
    // Beta 4.5: bolt, a 5K under 20 minutes.
    val NAMES = listOf("standard", "white", "gold", "glow", "lime", "blaze", "finisher", "fortyTwo", "bolt")

    private fun component(context: Context, name: String) =
        ComponentName(context, "me.tryfitos.app.Icon" + name.replaceFirstChar { it.uppercase() })

    private fun enabled(context: Context, name: String): Boolean =
        when (context.packageManager.getComponentEnabledSetting(component(context, name))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            // Never changed: the manifest's own value (only Standard is on).
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> name == "standard"
            else -> false
        }

    private fun launcher(context: Context): String =
        NAMES.firstOrNull { enabled(context, it) } ?: "standard"

    // Beta 4.1.1: the icon chosen but not switched yet (FITOS is in front).
    private const val PREFS = "fitos.appIcons"
    private const val PENDING = "pending"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** The chosen icon: the pending one, else the one on the launcher. */
    fun current(context: Context): String =
        prefs(context).getString(PENDING, null)?.takeIf { it in NAMES } ?: launcher(context)

    /** Remembers the choice; [applyPending] switches it when FITOS is left. */
    fun request(context: Context, name: String) {
        val edit = prefs(context).edit()
        if (name == launcher(context)) edit.remove(PENDING) else edit.putString(PENDING, name)
        edit.apply()
    }

    /**
     * Switches to the pending icon, if any. The pending choice is cleared
     * first (commit, not apply): the launcher may end the process at once.
     */
    fun applyPending(context: Context) {
        val name = prefs(context).getString(PENDING, null) ?: return
        prefs(context).edit().remove(PENDING).commit()
        if (name in NAMES && name != launcher(context)) choose(context, name)
    }

    /**
     * The new alias first, then the others off, so the launcher never sees an
     * app with no entry. DONT_KILL_APP keeps FITOS running, though some
     * launchers (Samsung's) still close it, so it runs only once FITOS is
     * left (applyPending).
     */
    private fun choose(context: Context, name: String) {
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
