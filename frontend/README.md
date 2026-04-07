# MaillardMap — marketing / support site (Firebase Hosting, **free Spark**)

Static **React (Vite)** site on **Firebase Hosting** only. No Cloud Functions (no Blaze billing required).

| Path | Purpose |
|------|--------|
| `/` | Home |
| `/support` | Contact form → **`POST` your Railway API** `/support/contact` (Resend) |
| `/privacy` | Privacy policy |
| `/verify-email?token=…` | Browser calls **`GET` your API** `/auth/verify-email` |

## Prerequisites

- Firebase CLI: `npm i -g firebase-tools` and `firebase login`
- Firebase project on the **Spark** plan (Hosting is free within [quotas](https://firebase.google.com/pricing))
- Railway API with **Resend** already configured, plus **`SUPPORT_INBOX_EMAIL`** (see `backend/README.md`)

## Build & deploy

From `frontend/`:

1. **`web/.env.production`** — set your public API URL (no trailing slash):

   ```bash
   echo 'VITE_API_BASE_URL=https://your-api.up.railway.app' > web/.env.production
   ```

2. Build and deploy:

   ```bash
   cd web && npm ci && npm run build && cd ..
   firebase deploy --only hosting
   ```

3. **Backend** (Railway): set **`SUPPORT_INBOX_EMAIL`** to the inbox that should receive support mail.

4. Optional: **`PUBLIC_EMAIL_CONFIRM_WEB_URL`** = your Firebase site URL so signup emails open `/verify-email` on this host (see `backend/README.md`).

## Local dev

```bash
cd web && npm ci && npm run dev
```

Create **`web/.env.local`** with `VITE_API_BASE_URL=http://localhost:3000` (or your Railway URL). The support form and verify page both call that API (CORS is open on the API today).

## Troubleshooting

- **Support form 503**: `SUPPORT_INBOX_EMAIL` or `RESEND_API_KEY` / `RESEND_FROM` missing on the API.
- **Verify page broken**: rebuild `web` with `VITE_API_BASE_URL` set; confirm the API allows browser CORS from your Firebase domain.
