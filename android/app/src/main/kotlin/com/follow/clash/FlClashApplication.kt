package com.follow.clash

import android.app.Application
import android.content.Context
import com.follow.clash.common.GlobalState
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter

class FlClashApplication : Application() {
    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        GlobalState.init(this)
    }

    override fun onCreate() {
        super.onCreate()
        val previousHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            runCatching {
                val directory = File(filesDir, "diagnostics").apply { mkdirs() }
                val trace = StringWriter().also { error.printStackTrace(PrintWriter(it)) }.toString()
                File(directory, "native-crash.log").appendText(
                    "[${System.currentTimeMillis()}] ${sanitize(trace)}\n",
                )
            }
            previousHandler?.uncaughtException(thread, error)
        }
    }

    private fun sanitize(value: String): String = value
        .replace(Regex("(?i)(authorization\\s*[:=]\\s*)([^\\s,;]+)"), "$1[REDACTED]")
        .replace(Regex("(?i)((?:token|password|secret|api[_-]?key)\\s*[:=]\\s*)([^\\s,;]+)"), "$1[REDACTED]")
        .replace(Regex("(?i)(bearer\\s+)[^\\s,;]+"), "$1[REDACTED]")
}
