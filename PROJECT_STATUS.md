# Innovestia implementation status

**Updated:** 19 October 2026  
**Scope:** Flutter client and Node.js/Express/MongoDB API in this repository.

## Implemented in this update

- Registration now requires matching password and confirm-password values. Both fields have independent show/hide controls; existing password strength checks and duplicate-submit/rate-limit handling remain in place.
- Startup and investor profiles now support the additional role-specific fields, full name, and editable contact number. Email stays read-only on the profile because changing a login email without a verification flow would be unsafe. Profile edits are stored through the authenticated user's API and the account session refreshes after saving.
- Monetary profile fields now carry an explicit `moneyCurrency` (`USD` or `INR`). New accounts start with USD. Existing profile values without a currency remain marked “currency not specified”; no conversion or assumed currency is applied. Owners can select the currency when editing.
- The dashboard greeting now uses the authenticated user's name, with “there” as a fallback.
- Discovery details show available public profile fields, explicit currency labels, and startup pitch deck access. A Message action opens the existing one-to-one conversation endpoint, which reuses the conversation for that participant pair.
- Both startups and investors can send a clearly labelled connection/investment request. Recipients can accept or decline; both sides can view status. The API validates roles and request ownership, handles duplicate pending requests, rejects stale transitions, and creates in-app notifications on send and decision.
- Added profile schema fields and a partial unique index for pending requests by startup, investor, and request type. Legacy interest endpoint remains available and maps into the same request workflow.

## Existing features retained

- Flutter startup/investor dashboards and role-based navigation.
- Login/registration, persisted JWT session, profile editing, discovery, saved profiles, investment requests, periodic-refresh messaging, notifications, admin user management, and PDF pitch-deck upload/download.
- Server-side authentication and role checks, password hashing, input validation, request/message authorization, and private local pitch-deck storage.

## Known gaps and data notes

- **Email OTP is not implemented in the checked-out source.** The supplied request says to preserve an existing OTP flow, but `backend/src/routes/authRoutes.js` currently exposes only register, login, session lookup, and logout. Resend/verification UI and API must be added as a separate feature before claiming verified email accounts.
- Email addresses are displayed only to the account owner; they are not included in public discovery profiles. Updating an account email is intentionally not offered without email verification.
- Currency cannot be inferred for old numeric amounts. There is no automatic INR-to-USD conversion or migration. Owners must identify and select the currency of their existing amounts. New accounts default to USD.
- Existing duplicate pending requests, if any, must be reviewed before MongoDB builds the new unique partial index. The unique constraint prevents new duplicates after the index is active.
- Pitch-deck storage remains local to one backend host. Durable object storage and deployment configuration are still production tasks.

## Files changed

- `lib/screens/auth/auth_screens.dart`
- `lib/screens/dashboard/dashboard_screen.dart`
- `lib/screens/features/feature_screens.dart`
- `lib/services/auth_service.dart`
- `backend/src/controllers/authController.js`
- `backend/src/controllers/resourceController.js`
- `backend/src/models/Profile.js`
- `backend/src/models/InvestmentRequest.js`
- `backend/src/routes/apiRoutes.js`

## Verification performed

- Backend `npm test`: **passed, 2 tests**.
- Node syntax checks for changed backend controllers/model: **passed**.
- `GET http://localhost:8081/health`: **HTTP 200**.
- `git diff --check`: **passed**.
- `dart format lib test`, `flutter analyze`, and `flutter test` were attempted. Dart/Flutter processes stalled without output in this environment and had to be stopped; their results are **unavailable**, not passing. The running API health check does not verify MongoDB-backed workflows.
- End-to-end registration, profile persistence, messaging, requests, and notification flows were not exercised against test accounts or a test database.

## Run locally

```powershell
npm --prefix backend install
npm --prefix backend run dev
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api
```

Use `http://localhost:8081/api` for Windows/Web and a reachable LAN or HTTPS URL for a physical device/release build. Backend MongoDB and JWT environment settings are described in [backend/README.md](backend/README.md); general Flutter setup is in [README.md](README.md).
