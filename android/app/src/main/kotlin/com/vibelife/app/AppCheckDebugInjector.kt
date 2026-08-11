package com.vibelife.app

import android.content.Context
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions

object AppCheckDebugInjector {
    private const val TAG = "VibeAppCheck"

    fun inject(context: Context, token: String) {
        if (token.isBlank()) {
            Log.w(TAG, "Debug token boş, enjeksiyon atlandı.")
            return
        }

        val options = FirebaseOptions.fromResource(context)
        if (options == null) {
            Log.e(TAG, "FirebaseOptions.fromResource null döndü.")
            return
        }

        val persistenceKey = FirebaseApp.getPersistenceKey(
            FirebaseApp.DEFAULT_APP_NAME,
            options,
        )
        val prefsName = "com.google.firebase.appcheck.debug.store.$persistenceKey"
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        prefs.edit().clear().apply()
        val ok = prefs.edit()
            .putString("com.google.firebase.appcheck.debug.DEBUG_SECRET", token)
            .commit()

        Log.i(TAG, "prefs=$prefsName commit=$ok token=${token.take(8)}...")
    }
}
