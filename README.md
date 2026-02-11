<!-- Open-source code. Copyright Mohamed Zaitoon 2025-2026. -->
# HRM Store

![GitHub Release](https://img.shields.io/github/v/release/mohamed-zaitoon/HRMStore?include_prereleases&style=for-the-badge)
![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)
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

## Code Overview

- Entrypoints  
  - `lib/main.dart`: Boots the user app; initializes Firebase, theme, remote config, OneSignal, sets `isAdminApp=false`.  
  - `lib/main_admin.dart`: Boots the admin app with `isAdminApp=true`, stores the flag in SharedPreferences, then launches `HrmStoreApp`.

- App shell  
  - `lib/app/hrm_store_app.dart`: Main `MaterialApp`; wires routes for user/admin, applies dynamic color + theme mode, guards web deep links, and uses `_WebTitleObserver` to update page title.  
  - `lib/features/platform/android_landing_page.dart`: Redirects Android web visitors to Play/side-load flow; shows buttons for app install/open with gradient background.

- Update flow  
  - `lib/services/update_manager.dart`: Checks Remote Config + GitHub releases, compares versions, shows update dialog, downloads APK to app files/Download, installs via root (`installApkRooted`) then normal `installApk`, with progress and fallbacks.  
  - `android/app/src/main/kotlin/com/mohamedzaitoon/hrmstore/UpdateChecker.kt`: Native helper to hit GitHub API (latest release), pick first `.apk` asset, compare versions.  
  - `android/app/src/main/kotlin/com/mohamedzaitoon/hrmstore/MainActivity.kt`: MethodChannel `tt_android_info` for sdk info, file read, integrity, uninstall/install, root install, fetchLatestApk bridge; uses FileProvider `${applicationId}.provider`.  
  - `android/app/src/main/AndroidManifest.xml`: Permissions (INSTALL_PACKAGES, storage, notifications), deep links, FileProvider via `res/xml/file_paths.xml`.

- Admin tools  
  - `lib/features/admin/admin_orders_screen.dart`: Admin dashboard for orders, filters, auto-refresh, wallet editing per order, receipts preview, menu navigation.  
  - `lib/features/admin/admin_wallets_screen.dart`: Streams Firestore `wallets`, extracts numbers from `number`/`numbers`/mixed strings, shows copyable cards.  
  - Other admin screens: prices, codes, availability, users, game packages under `lib/features/admin/`.

- User flows  
  - `lib/features/calculator/calculator_screen.dart`: Core purchase/shipping flow; initiates `UpdateManager.check` on start for native users; shows menu with manual update trigger.  
  - `lib/features/orders/orders_screen.dart`: Displays user orders; auto-assigns wallet numbers by pulling from Firestore `wallets` when missing.

- OneSignal / Notifications  
  - `lib/services/onesignal_service.dart`: Initializes OneSignal, registers user/admin externalId, permission prompts.

- Storage & FileProvider  
  - `android/app/src/main/res/xml/file_paths.xml`: Grants access to cache, files, and external files for FileProvider to serve APK/theme files.

- Deployment notes  
  - GitHub releases drive in-app updates; ensure each release has an `.apk` asset.  
  - Remote Config keys: `latest_version_name`, `allow_beta_updates`, `allow_alpha_updates`.  
  - Root install needs `su`; otherwise the standard installer is shown.

- Where to extend  
  - Add more admin pages by routing in `hrm_store_app.dart` and adding screens under `lib/features/admin/`.  
  - Update flow adjustments live in `update_manager.dart` (Dart) and `MainActivity.kt` (native).

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
