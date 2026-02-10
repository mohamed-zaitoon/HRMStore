// Open-source code. Copyright Mohamed Zaitoon 2025-2026.
package com.mohamedzaitoon.hrmstore

import android.os.Build
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL

object UpdateChecker {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    data class Result(
        val updateAvailable: Boolean,
        val latestVersion: String,
        val downloadUrl: String,
        val releaseNotes: String?
    )

    /**
     * Fetch latest release APK (first asset ending with .apk) from GitHub.
     * @param user GitHub user/org
     * @param repo GitHub repo
     * @param currentVersion current app versionName
     * @param callback returns map (for MethodChannel) or error message
     */
    fun fetchLatestApk(
        user: String,
        repo: String,
        currentVersion: String,
        callback: (Map<String, Any?>?, String?) -> Unit,
    ) {
        val apiUrl = "https://api.github.com/repos/$user/$repo/releases?per_page=1"

        scope.launch {
            try {
                val url = URL(apiUrl)
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "GET"
                conn.connectTimeout = 7000
                conn.readTimeout = 7000
                conn.setRequestProperty("User-Agent", "hrmstore-updater")
                conn.setRequestProperty("Accept", "application/vnd.github.v3+json")

                if (conn.responseCode != 200) {
                    withContext(Dispatchers.Main) {
                        callback(null, "GitHub error ${conn.responseCode}")
                    }
                    return@launch
                }

                val body = conn.inputStream.bufferedReader().use { it.readText() }
                val releases = JSONArray(body)
                if (releases.length() == 0) {
                    withContext(Dispatchers.Main) { callback(null, "No releases") }
                    return@launch
                }

                val latest = releases.getJSONObject(0)
                val version = latest.optString("tag_name").removePrefix("v")
                val notes = latest.optString("body", "")
                val assets = latest.optJSONArray("assets")
                var apkUrl = ""
                if (assets != null) {
                    for (i in 0 until assets.length()) {
                        val asset = assets.getJSONObject(i)
                        val name = asset.optString("name", "").lowercase()
                        if (name.endsWith(".apk")) {
                            apkUrl = asset.optString("browser_download_url", "")
                            break
                        }
                    }
                }

                val updateAvailable = compareVersions(version, currentVersion) > 0

                val map = mapOf(
                    "updateAvailable" to updateAvailable,
                    "latestVersion" to version,
                    "downloadUrl" to apkUrl,
                    "releaseNotes" to notes
                )

                withContext(Dispatchers.Main) { callback(map, null) }
            } catch (e: Exception) {
                Log.e("UpdateChecker", "fetch failed", e)
                withContext(Dispatchers.Main) { callback(null, e.message) }
            }
        }
    }

    // Compare version strings like 1.2.3 vs 1.2.10
    private fun compareVersions(a: String, b: String): Int {
        val pa = a.split('.').mapNotNull { it.toIntOrNull() }
        val pb = b.split('.').mapNotNull { it.toIntOrNull() }
        val max = maxOf(pa.size, pb.size)
        for (i in 0 until max) {
            val va = pa.getOrElse(i) { 0 }
            val vb = pb.getOrElse(i) { 0 }
            if (va != vb) return va.compareTo(vb)
        }
        return 0
    }
}
