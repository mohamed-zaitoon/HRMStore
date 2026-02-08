#include <jni.h>
#include <string>
#include <vector>
#include <algorithm>
#include <cctype>
#include <unistd.h>

/**
 * native-lib.cpp
 * - يحتوي على دوال JNI المستخدمة للتحقق من سلامة التطبيق وإرجاع بصمة توقيع متوقعة.
 * - تأكد أن اسم الحزمة في توقيع الدوال JNI يطابق applicationId (com.mohamedzaitoon.hrmstore).
 */

const int ENCRYPTION_KEY = 419;

// App Signature Key (SHA-1) - مشفرة باستخدام XOR مع المفتاح 419
std::vector<int> encryptedSignKey = {481, 406, 409, 480, 411, 409, 405, 407, 409, 485, 404, 409, 405, 480, 409, 402, 400, 409, 481, 411, 409, 401, 481, 409, 404, 480, 409, 486, 405, 409, 410, 401, 409, 487, 403, 409, 401, 485, 409, 486, 403, 409, 407, 407, 409, 480, 406, 409, 403, 480, 409, 404, 486, 409, 482, 410, 409, 411, 480};

// كلاسات مشبوهة - مشفرة باستخدام XOR مع المفتاح 419
std::vector<int> encryptedWeirdClass = {
        449, 458, 461, 396, 462, 471, 396, 464, 458, 452, 461, 450, 471,
        470, 465, 454, 396, 488, 458, 463, 463, 454, 465, 482, 467, 467,
        463, 458, 448, 450, 471, 458, 460, 461, 411, 402, 401
};

// كلاسات مشبوهة أخرى - مشفرة باستخدام XOR مع المفتاح 419
std::vector<int> encryptedWeirdClass2 = {
        449, 458, 461, 396, 462, 471, 396, 464, 458, 452, 461, 450, 471,
        470, 465, 454, 396, 488, 458, 463, 463, 454, 465, 482, 467, 467,
        463, 458, 448, 450, 471, 458, 460, 461
};

// كلاسات مشبوهة - مشفرة باستخدام XOR مع المفتاح 419
std::vector<int> encryptedkiller = {456, 458, 463, 463, 454, 465};

// دالة لفك تشفير النصوص المشفرة باستخدام XOR
std::string xorDecrypt(const std::vector<int>& input, int key) {
    std::string output;
    output.reserve(input.size());
    for (int val : input) {
        char decryptedChar = static_cast<char>(val ^ key);
        output.push_back(decryptedChar);
    }
    return output;
}

// JNI: jstring Java_com_mohamedzaitoon_hrmstore_NativeBridge_getNativeExpectedSHA1(JNIEnv*, jobject)
extern "C"
JNIEXPORT jstring JNICALL
Java_com_mohamedzaitoon_hrmstore_NativeBridge_getNativeExpectedSHA1(JNIEnv* env, jobject /*thiz*/) {
    std::string v = xorDecrypt(encryptedSignKey, ENCRYPTION_KEY);
    return env->NewStringUTF(v.c_str());
}

// JNI: jboolean Java_com_mohamedzaitoon_hrmstore_NativeBridge_checkAppIntegrity(JNIEnv*, jobject, jobject)
extern "C"
JNIEXPORT jboolean JNICALL
Java_com_mohamedzaitoon_hrmstore_NativeBridge_checkAppIntegrity(
        JNIEnv* env, jobject /*thiz*/, jobject /*context*/) {

    std::string weirdClass  = xorDecrypt(encryptedWeirdClass,  ENCRYPTION_KEY);
    std::string weirdClass2 = xorDecrypt(encryptedWeirdClass2, ENCRYPTION_KEY);
    std::string killerWord  = xorDecrypt(encryptedkiller,      ENCRYPTION_KEY);

    // محاولة إيجاد كلاسات مشبوهة
    jclass cls1 = env->FindClass(weirdClass.c_str());
    if (cls1 != nullptr) {
        _exit(0); // إغلاق فوري لو وجدنا تلاعب
        return JNI_FALSE;
    }
    env->ExceptionClear();

    jclass cls2 = env->FindClass(weirdClass2.c_str());
    if (cls2 != nullptr) {
        _exit(0);
        return JNI_FALSE;
    }
    env->ExceptionClear();

    // فحص ClassLoader ووجود كلمات مشبوهة في الوصف
    jclass classLoaderClass = env->FindClass("java/lang/ClassLoader");
    if (classLoaderClass != nullptr) {
        jmethodID getSystemClassLoader = env->GetStaticMethodID(
                classLoaderClass, "getSystemClassLoader", "()Ljava/lang/ClassLoader;");
        jobject systemClassLoader = env->CallStaticObjectMethod(classLoaderClass, getSystemClassLoader);

        if (systemClassLoader != nullptr) {
            jclass clClass = env->GetObjectClass(systemClassLoader);
            jmethodID toStringMethod = env->GetMethodID(clClass, "toString", "()Ljava/lang/String;");
            jstring clInfo = (jstring)env->CallObjectMethod(systemClassLoader, toStringMethod);

            const char* clChars = env->GetStringUTFChars(clInfo, nullptr);
            std::string clStr(clChars);
            env->ReleaseStringUTFChars(clInfo, clChars);

            std::string lower;
            lower.reserve(clStr.size());
            for (char c : clStr) lower.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(c))));

            std::string killerLower;
            killerLower.reserve(killerWord.size());
            for (char c : killerWord) killerLower.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(c))));

            if (lower.find(killerLower) != std::string::npos) {
                _exit(0);
                return JNI_FALSE;
            }
        }
    }

    return JNI_TRUE;
}
