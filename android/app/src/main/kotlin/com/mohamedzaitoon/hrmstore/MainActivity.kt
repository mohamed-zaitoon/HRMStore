// Open-source code. Copyright Mohamed Zaitoon 2025-2026.
package com.mohamedzaitoon.hrmstore

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.io.InputStream


class MainActivity: FlutterActivity() {
    private val CHANNEL = "tt_android_info"

    // EN: Configures Flutter engine and native channel handlers.
    // AR: تهيّئ محرك Flutter ومعالجات القناة الأصلية.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSdkInt" -> {
                    result.success(Build.VERSION.SDK_INT)
                }
                "readFileAsBytes" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr == null) {
                        result.error("NO_URI", "uri argument is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = Uri.parse(uriStr)
                        val bytes = readBytesFromUri(uri)
                        if (bytes != null) {
                            result.success(bytes)
                        } else {
                            result.error("READ_FAILED", "Could not read bytes from uri", null)
                        }
                    } catch (e: Exception) {
                        result.error("EXCEPTION", e.message, null)
                    }
                }
                "getNativeExpectedSHA1" -> {
                    try {
                        val s = NativeBridge.getNativeExpectedSHA1()
                        result.success(s)
                    } catch (e: Exception) {
                        result.error("NATIVE_ERROR", e.message, null)
                    }
                }
                "applyHyperBridgeTheme" -> {
                    val assetName = call.argument<String>("assetName")
                    if (assetName.isNullOrBlank()) {
                        result.error("NO_ASSET", "assetName is null or empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val ok = applyHyperBridgeTheme(assetName)
                        result.success(ok)
                    } catch (e: ActivityNotFoundException) {
                        result.error(
                            "HYPERBRIDGE_NOT_FOUND",
                            "HyperBridge is not installed",
                            null
                        )
                    } catch (e: IOException) {
                        result.error("ASSET_NOT_FOUND", e.message, null)
                    } catch (e: Exception) {
                        result.error("THEME_ERROR", e.message, null)
                    }
                }
                "checkAppIntegrity" -> {
                    try {
                        val ok = NativeBridge.checkAppIntegrity(this)
                        result.success(ok)
                    } catch (e: Exception) {
                        result.error("NATIVE_ERROR", e.message, null)
                    }
                }

                "isPackageInstalled" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg.isNullOrBlank()) {
                        result.error("NO_PACKAGE", "packageName is null or empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(pkg, 0)
                        }
                        result.success(true)
                    } catch (e: PackageManager.NameNotFoundException) {
                        result.success(false)
                    } catch (e: Exception) {
                        result.error("PACKAGE_ERROR", e.message, null)
                    }
                }
                "requestUninstallPackage" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg.isNullOrBlank()) {
                        result.error("NO_PACKAGE", "packageName is null or empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_DELETE).apply {
                            data = Uri.parse("package:$pkg")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        result.error("UNINSTALL_NOT_FOUND", e.message, null)
                    } catch (e: Exception) {
                        result.error("UNINSTALL_ERROR", e.message, null)
                    }
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("NO_PATH", "path is null or empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val ok = installApk(path)
                        if (ok) {
                            result.success(true)
                        } else {
                            result.error("INSTALL_FAILED", "Could not start installer", null)
                        }
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                "fetchLatestApk" -> {
                    val user = call.argument<String>("user")
                    val repo = call.argument<String>("repo")
                    val currentVersion = call.argument<String>("currentVersion") ?: ""
                    if (user.isNullOrBlank() || repo.isNullOrBlank()) {
                        result.error("BAD_ARGS", "user/repo are required", null)
                        return@setMethodCallHandler
                    }
                    UpdateChecker.fetchLatestApk(user, repo, currentVersion) { res, err ->
                        if (err != null) {
                            result.error("UPDATE_ERROR", err, null)
                        } else {
                            result.success(res)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // EN: Copies HyperBridge theme asset to cache and opens it in HyperBridge.
    // AR: تنسخ ملف الثيم إلى الكاش وتفتحه في HyperBridge.
    @Throws(IOException::class)
    private fun applyHyperBridgeTheme(assetName: String): Boolean {
        val cacheRoot = File(cacheDir, "hrmstore")
        if (!cacheRoot.exists()) {
            cacheRoot.mkdirs()
        }

        val fileName = assetName.substringAfterLast('/')
        val outFile = File(cacheRoot, fileName)
        if (!outFile.exists() || outFile.length() == 0L) {
            val assetKey = FlutterInjector.instance()
                .flutterLoader()
                .getLookupKeyForAsset(assetName)
            assets.open(assetKey).use { input ->
                outFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
        }

        val uri = FileProvider.getUriForFile(
            this,
            "${packageName}.hrmstore.provider",
            outFile
        )

        val intent = Intent("com.d4viddf.hyperbridge.APPLY_THEME").apply {
            setDataAndType(uri, "application/zip")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        startActivity(intent)
        return true
    }

    // EN: Installs an APK from the given path using FileProvider (no browser required).
    // AR: يثبّت ملف APK من المسار المحدد عبر FileProvider بدون الحاجة لفتح المتصفح.
    private fun installApk(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) {
            android.util.Log.e("UpdateInstaller", "APK file not found at $path")
            return false
        }
        android.util.Log.i("UpdateInstaller", "Installing APK at $path size=${file.length()}")

        val uri = FileProvider.getUriForFile(
            this,
            "${packageName}.provider",
            file
        )

        val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            data = uri
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
            putExtra(Intent.EXTRA_RETURN_RESULT, true)
        }

        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: Exception) {
            android.util.Log.e("UpdateInstaller", "Install intent failed", e)
            false
        }
    }


    // EN: Reads bytes from a content URI.
    // AR: تقرأ البايتات من عنوان URI للمحتوى.
    private fun readBytesFromUri(uri: Uri): ByteArray? {
        var inputStream: InputStream? = null
        return try {
            inputStream = contentResolver.openInputStream(uri)
            if (inputStream == null) return null
            val buffer = ByteArrayOutputStream()
            val data = ByteArray(8192)
            var nRead: Int
            while (inputStream.read(data, 0, data.size).also { nRead = it } != -1) {
                buffer.write(data, 0, nRead)
            }
            buffer.flush()
            buffer.toByteArray()
        } catch (e: Exception) {
            null
        } finally {
            try { inputStream?.close() } catch (_: Exception) {}
        }
    }
}
