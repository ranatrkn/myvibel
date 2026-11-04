package com.myvibel.app

import android.app.Application
import android.content.Context

class MyVibelApplication : Application() {
    override fun attachBaseContext(base: Context) {
        if (BuildConfig.DEBUG) {
            val token = base.getString(R.string.app_check_debug_token)
            AppCheckDebugInjector.inject(base, token)
        }
        super.attachBaseContext(base)
    }
}
