# Cloudflare Worker Notifications (Free)

This setup replaces paid Firebase Functions for push sending.
Client apps call a Cloudflare Worker, and the Worker sends to OneSignal.

## 1) Deploy Worker

1. Install Wrangler:

```bash
npm i -g wrangler
```

2. Login:

```bash
wrangler login
```

3. Copy worker files:

```bash
cd cloudflare
cp wrangler.toml.example wrangler.toml
```

4. Set secrets:

```bash
wrangler secret put ONESIGNAL_APP_ID
wrangler secret put ONESIGNAL_REST_KEY
wrangler secret put WORKER_TOKEN
```

5. Deploy:

```bash
wrangler deploy
```

Save the deployed URL (example: `https://hrmstore-onesignal-relay.<subdomain>.workers.dev`).

## 2) Remote Config Keys

Add these keys in Firebase Remote Config:

- `cloudflare_notify_enabled` = `true`
- `cloudflare_client_sender_enabled` = `true`
- `cloudflare_notify_url` = `https://<your-worker-url>`
- `cloudflare_notify_token` = `<WORKER_TOKEN>`
- `notification_mode` = `onesignal`
- `cloudflare_admin_whatsapp` = `<admin whatsapp digits>` (optional)

Also keep:

- `onesignal_app_id` = your OneSignal app id

## 3) App Behavior

- User creates order -> admin gets push.
- User uploads receipt -> admin gets push.
- Admin updates order status -> user gets push.
- User requests Ramadan code -> admin gets push.
- Admin sends code -> user gets push.

## 4) Notes

- This is fully free on Cloudflare Worker free tier.
- Push still relies on OneSignal delivery.
- Protect Worker with `WORKER_TOKEN` and do not expose OneSignal REST key in the app.
- To prevent duplicates, keep Firebase Function-based notification triggers disabled:
  - `functions/.env.<project-id>` -> `ENABLE_FUNCTION_NOTIFICATIONS=false`

## 5) One-Command Setup (after Cloudflare login)

If you already logged into Wrangler, run:

```bash
./tools/setup_cloudflare_notifications.sh hrmstore
```

This command will:

- Create/update Worker secrets from current Firebase Remote Config (`onesignal_app_id`, `onesignal_reset_api`)
- Deploy the Worker
- Auto-write these Remote Config keys:
  - `cloudflare_notify_enabled`
  - `cloudflare_notify_url`
  - `cloudflare_notify_token`
  - `cloudflare_admin_whatsapp`
