package com.maillardmap

import android.app.Application
import com.maillardmap.data.RetrofitClient
import com.maillardmap.data.SessionManager

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    companion object {
        lateinit var instance: MainApplication
            private set
    }
}
