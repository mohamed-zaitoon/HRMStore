# HRM Store - Code Overview

This document gives a concise, high-signal map of the codebase without modifying source files.

## Flutter entrypoints
- `lib/main.dart`: Boots the user app; initializes Firebase, theme, remote config, OneSignal, sets `isAdminApp=false`.
- `lib/main_admin.dart`: Boots the admin app with `isAdminApp=true`, stores the flag in SharedPreferences, then launches `HrmStoreApp`.

## App shell
- `lib/app/hrm_store_app.dart`: Main `MaterialApp`; wires routes for user/admin, applies dynamic color + theme mode, guards web deep links, and uses `_WebTitleObserver` to update page title.

## Platform landing
- `lib/features/platform/android_landing_page.dart`: Redirects Android web visitors to Play/side-load flow; shows buttons for app install/open with gradient background.

## Update flow
- `lib/services/update_manager.dart`: Checks Remote Config + GitHub releases, compares versions, and shows update dialog. Downloads APK to app files/Download, then installs: tries root (`installApkRooted` channel) then normal `installApk`. Handles progress, HTTPS hardening, and fallbacks.
- `android/app/src/main/kotlin/com/mohamedzaitoon/hrmstore/UpdateChecker.kt`: Native helper to hit GitHub API (latest release), pick first `.apk` asset, compare versions.
- `android/app/src/main/kotlin/com/mohamedzaitoon/hrmstore/MainActivity.kt`: MethodChannel `tt_android_info` handlers: getSdkInt, readFileAsBytes, applyHyperBridgeTheme, integrity checks, package install/uninstall, rooted install (`pm install -r`), and fetchLatestApk bridge. Uses FileProvider `${applicationId}.provider`.
- `android/app/src/main/AndroidManifest.xml`: Declares permissions (INSTALL_PACKAGES, storage, notifications), deep links, FileProvider with `file_paths.xml`.

## Admin tools
- `lib/features/admin/admin_orders_screen.dart`: Main admin dashboard for orders, filters, auto-refresh, wallet editing per order, receipts preview, menu to other admin sections.
- `lib/features/admin/admin_wallets_screen.dart`: Lists all wallets from Firestore `wallets` collection; extracts numbers from `number`, `numbers`, or mixed strings; renders copyable cards.
- Other admin screens: prices, codes, availability, users, game packages; each under `lib/features/admin/`.

## User flows
- `lib/features/calculator/calculator_screen.dart`: Core purchase/shipping flow; initiates `UpdateManager.check` on start for native users; shows menu with manual update trigger.
- `lib/features/orders/orders_screen.dart`: Displays user orders; auto-assigns wallet numbers by pulling from Firestore `wallets` when missing.

## OneSignal / Notifications
- `lib/services/onesignal_service.dart` (not opened but referenced): Initializes OneSignal, registers user/admin externalId, permission prompts.

## Storage & FileProvider
- `android/app/src/main/res/xml/file_paths.xml`: Grants access to cache, files, and external files for FileProvider to serve APK/theme files.

## Deployment notes
- GitHub releases drive in-app updates; ensure each release has an `.apk` asset.
- Remote Config keys: `latest_version_name`, `allow_beta_updates`, `allow_alpha_updates`.
- For rooted install to succeed, `su` must be available; otherwise user sees the standard installer.

## Where to extend
- Add more admin pages by routing in `hrm_store_app.dart` and adding screens under `lib/features/admin/`.
- Update flow adjustments live in `update_manager.dart` (Dart) and `MainActivity.kt` (native).

---
For deeper API-level docs, prefer `dart doc` for Dart code and KDoc for Kotlin; this file stays high-level to avoid code churn.
