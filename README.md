<!-- Open-source code. Copyright Mohamed Zaitoon 2025-2026. -->
# HRM Store

HRM Store is an Arabic-first commerce platform built with Flutter for selling digital balance and TikTok coin packages through a guided order flow and an operations dashboard.

The product combines a customer-facing app with internal admin tooling so orders, pricing, receipts, availability, and support can be managed from one system. In production, the platform uses Firebase for backend services and configuration, plus OneSignal-based notifications with a Cloudflare relay layer.

This public repository is intentionally limited. The production implementation now lives in a private repository, while this repo keeps high-level documentation and safe example configuration files that help explain the project without exposing operational logic, secrets, or proprietary code.

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
