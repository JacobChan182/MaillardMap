package com.bigback

import android.app.Application
import com.bigback.data.RetrofitClient
import com.bigback.data.SessionManager

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
