<!-- Open-source code. Copyright Mohamed Zaitoon 2025-2026. -->
# HRM Store

![GitHub Release](https://img.shields.io/github/v/release/mohamed-zaitoon/HRMStore?include_prereleases&style=for-the-badge)
![GitHub License](https://img.shields.io/github/license/mohamed-zaitoon/HRMStore?style=for-the-badge)
![Last Commit](https://img.shields.io/github/last-commit/mohamed-zaitoon/HRMStore?style=for-the-badge)

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=firebase&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Web](https://img.shields.io/badge/Web-4285F4?style=for-the-badge&logo=google-chrome&logoColor=white)

HRM Store is a Flutter application for purchasing TikTok coins with a smooth, Arabic‑first experience. It runs on Android and Web and uses Firebase for data, configuration, and notifications.

## Highlights

- Cross‑platform Flutter app (Android + Web)
- Arabic‑first UI with RTL support and modern glassmorphism design
- Dynamic pricing rules stored in Firestore
- Orders flow with receipt uploads and status tracking
- Remote Config for operational settings and offers
- OneSignal notifications

## Code Overview / نظرة عامة على الكود

- Entrypoints / نقاط الدخول  
  - `lib/main.dart`: boots the user app, initializes Firebase/Remote Config/OneSignal with `isAdminApp=false`.  
  - `lib/main_admin.dart`: boots the admin app, sets `isAdminApp=true`, persists the flag in SharedPreferences.

- App shell / الهيكل العام  
  - `lib/app/hrm_store_app.dart`: main `MaterialApp`, routes for user/admin, dynamic color + theme mode, web title observer.  
  - `lib/features/platform/android_landing_page.dart`: redirects Android web visitors to install/open app with gradient CTA.

- Update flow / نظام التحديث  
  - `lib/services/update_manager.dart`: checks Remote Config + GitHub releases, downloads APK to `files/Download`, installs via root (`installApkRooted`) then normal `installApk`, shows progress and fallbacks.  
  - `android/app/src/main/kotlin/com/mohamedzaitoon/hrmstore/UpdateChecker.kt`: GitHub latest release fetcher, picks first `.apk` asset, compares versions.  
  - `android/app/src/main/kotlin/com/mohamedzaitoon/hrmstore/MainActivity.kt`: MethodChannel `tt_android_info` for sdk info, file read, integrity, uninstall/install, root install, fetchLatestApk bridge; uses FileProvider `${applicationId}.provider`.  
  - `android/app/src/main/AndroidManifest.xml`: permissions (INSTALL_PACKAGES, storage, notifications), deep links, FileProvider per `res/xml/file_paths.xml`.

- Admin tools / أدوات الأدمن  
  - `lib/features/admin/admin_orders_screen.dart`: admin dashboard for orders, filters, wallet editing per order, receipts preview, menu navigation.  
  - `lib/features/admin/admin_wallets_screen.dart`: streams Firestore `wallets`, extracts numbers from `number`/`numbers`/mixed strings, shows copyable cards.  
  - Other admin screens: prices, promo codes, availability, users, game packages under `lib/features/admin/`.

- User flows / تدفقات المستخدم  
  - `lib/features/calculator/calculator_screen.dart`: core purchase flow; runs `UpdateManager.check` on app start; manual update button in menu.  
  - `lib/features/orders/orders_screen.dart`: shows user orders; auto-assigns wallet numbers from Firestore `wallets` when missing.

- OneSignal / الإشعارات  
  - `lib/services/onesignal_service.dart`: initializes OneSignal, sets externalId per user/admin, handles permissions.

- Storage & FileProvider / التخزين وموفر الملفات  
  - `android/app/src/main/res/xml/file_paths.xml`: grants cache/files/external_files for FileProvider to serve APK/theme assets.

- Deployment notes / ملاحظات النشر  
  - GitHub releases must include an `.apk` asset for in-app updates.  
  - Remote Config keys: `latest_version_name`, `allow_beta_updates`, `allow_alpha_updates`.  
  - Root install needs available `su`; otherwise the user sees the normal installer.

## Tech Stack

- Flutter (stable)
- Dart
- Firebase: Firestore, Remote Config, Cloud Functions, Hosting
- OneSignal

## Project Structure

- `lib/` Flutter app source
- `functions/` Firebase Cloud Functions (Node.js)
- `web/` Web assets
- `firebase.json` Firebase configuration

## Firebase Services

- Firestore (orders, prices, promo codes, code requests)
- Remote Config (offers, toggles, contact info)
- Cloud Functions (notifications and automation)
- Hosting (Web app)

## Firestore Collections (Core)

- `orders` user orders and status
- `prices` pricing tiers (min, max, pricePer1000)
- `promo_codes` discount codes
- `code_requests` Ramadan code requests
- `onesignal_players` OneSignal device registry

## Remote Config

Key parameters used by the app:

- `wallet_number`
- `instapay_link`
- `offer5`
- `offer50`
- `is_ramadan`
- `admin_enabled`
- `onesignal_app_id`
- `onesignal_reset_api`

## OneSignal

External IDs are role‑scoped for user devices:

- `user:<whatsapp>`

## Development

### Prerequisites

- Flutter SDK (stable)
- Firebase CLI
- Node.js 22 (for Cloud Functions)

## Deployment

- Functions deployment via Firebase CLI
- Web hosting via Firebase Hosting

## Notes

- Do not commit `.env.<projectId>` files.
- Keep your Firebase project roles updated for Functions deployment.

## License

MIT. See `LICENSE`.
