package com.mohamedzaitoon.hrmstore

import android.content.Context

/**
 * NativeBridge object
 * - يحمّل المكتبة native ويعرّف الدوال الخارجية (JNI).
 * - يجب أن يتطابق اسم المكتبة هنا مع اسم add_library في CMake (hrmstore).
 */
object NativeBridge {
    init {
        System.loadLibrary("hrmstore")
    }

    external fun getNativeExpectedSHA1(): String
    external fun checkAppIntegrity(context: Context): Boolean
}
