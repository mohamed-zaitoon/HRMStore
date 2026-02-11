# HRM Store — Code Overview / نظرة عامة على الكود

This document gives a concise, high‑signal map of the codebase without modifying source files. (English + Arabic)

## Flutter entrypoints / نقاط الدخول
- `lib/main.dart`  
  - EN: Boots the user app; initializes Firebase, theme, remote config, OneSignal, sets `isAdminApp=false`.  
  - AR: يشغّل نسخة المستخدم، يهيئ خدمات Firebase والثيم و Remote Config و OneSignal، ويثبت علم `isAdminApp=false`.
- `lib/main_admin.dart`  
  - EN: Boots the admin app with `isAdminApp=true`, stores the flag in SharedPreferences, then launches `HrmStoreApp`.  
  - AR: يشغّل نسخة الأدمن مع ضبط `isAdminApp=true` في الإعدادات ثم يفتح `HrmStoreApp`.

## App shell / الهيكل العام
- `lib/app/hrm_store_app.dart`  
  - EN: Main `MaterialApp`; wires routes for user/admin, applies dynamic color + theme mode, guards web deep links, and uses `_WebTitleObserver` to update page title.  
  - AR: الـ `MaterialApp` الرئيسي؛ يضبط المسارات للمستخدم والأدمن، يطبق الألوان الديناميكية ووضع الثيم، ويتابع عناوين الصفحات على الويب.

## Platform landing / شاشة التحويل
- `lib/features/platform/android_landing_page.dart`  
  - EN: Redirects Android web visitors to Play/side‑load flow; shows buttons for app install/open with gradient background.  
  - AR: يوجّه زوار الويب على أندرويد إلى مسار التحميل أو الفتح؛ يعرض أزرار التثبيت/الفتح مع خلفية متدرجة.

## Update flow / نظام التحديث
- `lib/services/update_manager.dart`  
  - EN: Checks Remote Config + GitHub releases, compares versions, and shows update dialog. Downloads APK to app files/Download, then installs: tries root (`installApkRooted` channel) then normal `installApk`. Handles progress, HTTPS hardening, and fallbacks.  
  - AR: يفحص Remote Config وإصدارات GitHub، يقارن الإصدارات، يعرض حوار التحديث، ينزّل الـAPK إلى مجلد التطبيق ثم يحاول التثبيت بروت أولاً ثم التثبيت العادي، مع شريط تقدم ومعالجات أخطاء.
- `android/app/src/main/kotlin/com/mohamedzaitoon/hrmstore/UpdateChecker.kt`  
  - EN: Native helper to hit GitHub API (latest release), pick first `.apk` asset, compare versions.  
  - AR: كلاس مساعد على أندرويد يجلب آخر إصدار من GitHub ويختار أصل الـAPK ويقارن الإصدارات.
- `android/app/src/main/kotlin/com/mohamedzaitoon/hrmstore/MainActivity.kt`  
  - EN: MethodChannel `tt_android_info` handlers: getSdkInt, readFileAsBytes, applyHyperBridgeTheme, integrity checks, package install/uninstall, rooted install (`pm install -r`), and fetchLatestApk bridge. Uses FileProvider `${applicationId}.provider`.  
  - AR: معالجات القناة لتوفير معلومات النظام والتعامل مع التثبيت/الإزالة، والتثبيت بالروت، وجسر تحميل أحدث APK.
- `android/app/src/main/AndroidManifest.xml`  
  - EN: Declares permissions (INSTALL_PACKAGES, storage, notifications), deep links, FileProvider with `file_paths.xml`.  
  - AR: يعلن الأذونات وروابط العمق وموفر الملفات وفق `file_paths.xml`.

## Admin tools / أدوات الأدمن
- `lib/features/admin/admin_orders_screen.dart`  
  - EN: Main admin dashboard for orders, filters, auto‑refresh, wallet editing per order, receipts preview, menu to other admin sections.  
  - AR: لوحة تحكم الطلبات للأدمن مع التحديث التلقائي، تعديل رقم المحفظة لكل طلب، عرض الإيصالات، وقائمة التنقل.
- `lib/features/admin/admin_wallets_screen.dart`  
  - EN: Lists all wallets from Firestore `wallets` collection; extracts numbers from `number`, `numbers`, or mixed strings; renders copyable cards.  
  - AR: يعرض كل المحافظ من مجموعة `wallets`، يستخرج الأرقام من الحقول المختلفة ويعرض بطاقات قابلة للنسخ.
- Other admin screens: prices, codes, availability, users, game packages; each under `lib/features/admin/`.

## User flows / تدفقات المستخدم
- `lib/features/calculator/calculator_screen.dart`  
  - EN: Core purchase/shipping flow; initiates `UpdateManager.check` on start for native users; shows menu with manual update trigger.  
  - AR: شاشة الطلب الأساسية؛ تستدعي فحص التحديث عند البدء في التطبيق الأصلي وتتيح زر تحديث يدوي.
- `lib/features/orders/orders_screen.dart`  
  - EN: Displays user orders; auto‑assigns wallet numbers by pulling from Firestore `wallets` when missing.  
  - AR: يعرض طلبات المستخدم ويولّد رقم محفظة تلقائياً عند غيابه بالاعتماد على مجموعة `wallets`.

## OneSignal / Notifications
- `lib/services/onesignal_service.dart` (not opened but referenced)  
  - EN: Initializes OneSignal, registers user/admin externalId, permission prompts.  
  - AR: يهيئ OneSignal ويحدّث externalId للمستخدم أو الأدمن ويطلب الأذونات.

## Storage & FileProvider
- `android/app/src/main/res/xml/file_paths.xml`  
  - EN: Grants access to cache, files, and external files for FileProvider to serve APK/theme files.  
  - AR: يحدد مسارات الكاش والملفات الداخلية والخارجية لتمريرها عبر FileProvider.

## Deployment notes / ملاحظات النشر
- GitHub releases drive in‑app updates; ensure each release has an `.apk` asset.  
- Remote Config keys: `latest_version_name`, `allow_beta_updates`, `allow_alpha_updates`.  
- For rooted install to succeed, `su` must be available; otherwise user sees the standard installer.

## Where to extend / أماكن التوسيع
- Add more admin pages by routing in `hrm_store_app.dart` and adding screens under `lib/features/admin/`.  
- Update flow adjustments live in `update_manager.dart` (Dart) and `MainActivity.kt` (native).

---
For deeper API‑level docs, prefer `dart doc` for Dart code and KDoc for Kotlin; this file stays high‑level to avoid code churn. / للحصول على توثيق أعمق استخدم أدوات التوثيق الآلية؛ هذا الملف يقدّم خريطة عامة دون تعديل الكود.
