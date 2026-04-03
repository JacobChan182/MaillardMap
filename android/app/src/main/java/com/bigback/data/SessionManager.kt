package com.maillardmap.data

import android.content.Context
import android.content.SharedPreferences
import com.maillardmap.domain.User

/**
 * Manages session persistence using SharedPreferences.
 */
class SessionManager(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("maillardmap_prefs", Context.MODE_PRIVATE)

    companion object {
        private const val PREF_TOKEN = "auth_token"
        private const val PREF_USER_ID = "user_id"
        private const val PREF_USERNAME = "username"
    }

    fun saveSession(token: String, user: com.maillardmap.domain.User) {
        prefs.edit()
            .putString(PREF_TOKEN, token)
            .putString(PREF_USER_ID, user.id)
            .putString(PREF_USERNAME, user.username)
            .apply()
    }

    fun getToken(): String? = prefs.getString(PREF_TOKEN, null)
    fun getUserId(): String? = prefs.getString(PREF_USER_ID, null)
    fun getUsername(): String? = prefs.getString(PREF_USERNAME, null)

    fun isLoggedIn(): Boolean = getToken() != null

    fun clearSession() {
        prefs.edit().clear().apply()
    }
}
