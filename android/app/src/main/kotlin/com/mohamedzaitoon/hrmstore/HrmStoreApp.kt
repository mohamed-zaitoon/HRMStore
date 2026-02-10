// Open-source code. Copyright Mohamed Zaitoon 2025-2026.
package com.mohamedzaitoon.hrmstore

import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import android.os.Process
import apputilx.Utils
import com.mohamedzaitoon.hrmstore.NativeBridge
import com.onesignal.OneSignal

class HrmStoreApp : Application() {

    companion object {
        lateinit var context: Context
            private set
    }

    override fun attachBaseContext(base: Context) {

        super.attachBaseContext(base)
        // محاولة فحص السلامة مبكراً
        runCatching { NativeBridge.checkAppIntegrity(base) }
    }

    override fun onCreate() {
        super.onCreate()
        context = applicationContext

        // 1. تهيئة Utils أولاً (مهم جداً لتعمل باقي الدوال)
        Utils.initialize(this)

        // 2. تسجيل Activity Tracker الموجود في Utils
        registerActivityLifecycleCallbacks(Utils.activityTracker)

        // 3. تهيئة OneSignal مبكراً باستخدام app id من الـ manifest
        initOneSignalIfPossible()

        // 5. فحص الأمان (Native)
        runCatching { NativeBridge.checkAppIntegrity(this) }
            .onFailure { e -> Utils.logError("NativeBridge", "Integrity Check Failed", e) }

        // 6. التحقق من التوقيع
        verifyAppSignature()
    }

    private fun initOneSignalIfPossible() {
        val appId = try {
            val info = packageManager.getApplicationInfo(
                packageName,
                PackageManager.GET_META_DATA
            )
            info.metaData?.getString("onesignal_app_id")
        } catch (_: Exception) {
            null
        }

        if (!appId.isNullOrBlank()) {
            runCatching { OneSignal.initWithContext(this, appId) }
        }
    }


    private fun verifyAppSignature() {
        try {
            // جلب التوقيع الأصلي من مكتبة C++
            val expectedSignature = NativeBridge.getNativeExpectedSHA1()

            // استخدام Utils للتحقق من التوقيع الحالي
            val isValid = Utils.validateAppSignature(expectedSignature)

            if (!isValid) {
                // تسجيل محاولة العبث قبل الإغلاق
                Utils.logError("Security", "Signature Mismatch! App is modified.")
                throw SecurityException("Application Signature Mismatch")
            }
        } catch (e: Throwable) {
            // إغلاق التطبيق فوراً في حالة التلاعب
            Process.killProcess(Process.myPid())
            System.exit(0)
        }
    }
}
