package com.maillardmap

import android.app.Application
import com.mapbox.common.MapboxOptions
import com.maillardmap.R

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val token = getString(R.string.mapbox_access_token).trim()
        if (token.isNotEmpty()) {
            MapboxOptions.accessToken = token
        }
        instance = this
    }

    companion object {
        lateinit var instance: MainApplication
            private set
    }
}
