package com.follow.clash.common

import android.content.ComponentName

object Components {
    const val PACKAGE_NAME = "app.yyjc.pro"
    private const val NATIVE_NAMESPACE = "com.follow.clash"

    val mainActivity =
        ComponentName(GlobalState.packageName, "$NATIVE_NAMESPACE.MainActivity")

    val quickActionActivity =
        ComponentName(GlobalState.packageName, "$NATIVE_NAMESPACE.QuickActionActivity")

    val serviceBroadcastReceiver =
        ComponentName(GlobalState.packageName, "$NATIVE_NAMESPACE.ServiceBroadcastReceiver")
}
