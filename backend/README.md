# Innovestia API

If `backend/.env` does not exist, copy `.env.example` to `.env`; otherwise preserve its existing secrets and edit only the values that need changing. The MongoDB URI must select the app-only `innovestia_app` database. Set a secure `JWT_SECRET` and configure `RESEND_API_KEY` plus `EMAIL_FROM` with a sender domain verified with Resend. Run `npm install` and `npm run dev` from this directory, or use `npm --prefix backend run dev` from the project root.

The API never logs OTPs or credentials. Verification codes expire after 10 minutes; resend is limited to once per minute per account and also protected by the auth route rate limit. A provider rejection returns an error instead of a false sent confirmation.

Pitch decks are stored outside MongoDB in a private directory (`PITCH_DECK_DIR`, default `./private_uploads/pitch_decks`) and served only through authenticated, authorized API requests. Use a persistent mounted volume, restrict filesystem access to the backend service account, and include that volume in encrypted backups. The local storage driver is intended for a single backend host; configure a durable shared object store before horizontal scaling. Uploads are limited to 10 MB and checked as PDFs on the server.
