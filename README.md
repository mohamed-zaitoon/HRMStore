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
![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)

HRM Store is an Arabic-first commerce platform built with Flutter for selling digital balance and TikTok coin packages through a guided order flow and an operations dashboard.

The product combines a customer-facing app with internal admin tooling so orders, pricing, receipts, availability, and support can be managed from one system. In production, the platform uses Firebase for backend services and configuration, plus OneSignal-based notifications with a Cloudflare relay layer.

This public repository is intentionally limited. The production implementation now lives in a private repository, while this repo keeps high-level documentation and safe example configuration files that help explain the project without exposing operational logic, secrets, or proprietary code.

## Current Public Project Info

- App version: `1.6.2+162`
- Flutter: `3.41.0` (stable)
- Dart: `3.11.0`
- Platforms: Android, Web, and Windows for admin tooling

## What The Project Does

- Lets customers place digital orders through a mobile/web experience
- Supports pricing rules, promo offers, and operational toggles
- Tracks orders and payment receipts
- Provides an admin dashboard for order handling and support workflows
- Uses push notifications for important order and account events

## High-Level Stack

- Flutter and Dart for the app experience
- Firebase for data, configuration, hosting, and automation
- OneSignal for notifications
- Cloudflare Worker relay for notification delivery control

## Why This Public Repo Is Minimal

The public repository exists to document the project idea and preserve safe integration examples. It does not include the full application source code, private infrastructure logic, production credentials, or deployment-specific business rules.

## Included Here

- Product overview and repository-level documentation
- Safe example config files for Firebase, signing, and Cloudflare setup
- Licensing information for the public repo

## Example Files Kept Public

- `functions/.env.example`
- `android/app/google-services.json.example`
- `android/app/key.properties.example`
- `ios/Runner/GoogleService-Info.plist.example`
- `lib/firebase_options.dart.example`
- `cloudflare/wrangler.toml.example`

## Live Project

- Website: `https://hrmstore.mohamedzaitoon.com/`

## License

This repository remains under the [MIT License](LICENSE).
