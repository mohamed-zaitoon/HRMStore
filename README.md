<!-- Open-source code. Copyright Mohamed Zaitoon 2025-2026. -->
# HRM Store

![GitHub Release](https://img.shields.io/github/v/release/mohamed-zaitoon/HRM-Store?include_prereleases&style=for-the-badge)
![GitHub License](https://img.shields.io/github/license/mohamed-zaitoon/HRM-Store?style=for-the-badge)
![Last Commit](https://img.shields.io/github/last-commit/mohamed-zaitoon/HRM-Store?style=for-the-badge)

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
