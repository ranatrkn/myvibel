package com.vibelife.app

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.util.Log

/**
 * Firebase başlamadan önce debug token yazar (attachBaseContext'ten de çağrılır).
 */
class AppCheckDebugInitProvider : ContentProvider() {
    override fun onCreate(): Boolean {
        val ctx = context ?: return false
        val token = ctx.getString(R.string.app_check_debug_token)
        if (token.isNotBlank()) {
            AppCheckDebugInjector.inject(ctx, token)
            Log.i(TAG, "App Check debug token enjekte edildi.")
        }
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    companion object {
        private const val TAG = "VibeAppCheck"
    }
}
