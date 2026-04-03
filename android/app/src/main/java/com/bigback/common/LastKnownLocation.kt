package com.maillardmap.common

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.core.content.ContextCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Best recent fix from GPS / network / passive, or null if unavailable or no permission. */
suspend fun Context.lastKnownLatLng(): Pair<Double, Double>? = withContext(Dispatchers.IO) {
    val fine =
        ContextCompat.checkSelfPermission(this@lastKnownLatLng, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    val coarse =
        ContextCompat.checkSelfPermission(this@lastKnownLatLng, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    if (!fine && !coarse) return@withContext null

    val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
    fun safeLast(provider: String) =
        try {
            lm.getLastKnownLocation(provider)
        } catch (_: SecurityException) {
            null
        }
    val candidates =
        listOfNotNull(
            safeLast(LocationManager.GPS_PROVIDER),
            safeLast(LocationManager.NETWORK_PROVIDER),
            safeLast(LocationManager.PASSIVE_PROVIDER),
        )
    val best = candidates.maxByOrNull { it.time } ?: return@withContext null
    best.latitude to best.longitude
}
