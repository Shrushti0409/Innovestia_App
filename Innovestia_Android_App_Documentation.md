% Innovestia
% MCA Project Report — Android Application
% Source review: 10 October 2026

# Innovestia: Startup and Investor Collaboration Platform

**Submitted by:** [Student Name]  
**Student ID / Roll Number:** [To be completed]  
**Programme:** Master of Computer Applications (MCA)  
**Department / Institution:** [To be completed]  
**Project Guide:** [To be completed]  
**Academic Year:** [To be completed]

# Declaration

I declare that this report describes the Innovestia application as implemented in the supplied project source. Personal, institutional, and originality statements must be completed and approved by the student and institution.

Student: [Name]  Signature: ____________________  Date: ____________________

# Certificate

This is to certify that the project report entitled “Innovestia: Startup and Investor Collaboration Platform” is submitted by [Student Name], [Roll Number], in partial fulfilment of the requirements for the MCA programme at [Institution Name].

Project Guide: ____________________  Head of Department: ____________________  Date: __________

# Acknowledgement

[Complete with acknowledgements approved by the student. No names or institution details were supplied.]

# Abstract

Innovestia is a Flutter Android application backed by a Node.js and Express REST API and MongoDB. It provides role-based accounts for startups and investors, profile management and discovery, saved profiles, investment-interest requests, one-to-one conversations, notifications, and startup pitch-deck management. An administrator role has protected user-management and summary endpoints. The Flutter client stores JWT session data using Flutter Secure Storage. Mongoose models define users, profiles, saved profiles, investment requests, conversations, messages, and notifications.

This report is based on direct inspection of Flutter and backend source, model schemas, API routes, configuration, tests, and README. It distinguishes code-backed features from unverified workflows. OTP verification, email delivery, push notifications, investment execution, and an analytics suite were not found as implemented flows. No app screenshots or existing Word template were supplied. Student and institution details remain placeholders.

**Keywords:** Flutter, Dart, Node.js, Express, MongoDB, Mongoose, REST API, Android.

# 1. Introduction

## 1.1 Background and Problem Statement

Startups need a structured way to present business information and funding needs to potential investors. Investors need to identify relevant ventures and begin conversations. Discovery and follow-up can be fragmented across informal channels. Innovestia brings profile discovery, interest requests, messages, and notifications into one client-server application.

## 1.2 Motivation, Objectives and Scope

The project demonstrates a full-stack mobile application with Startup, Investor, and Admin roles. Objectives are to provide accounts; maintain role-specific profiles; discover opposite-role profiles; save profiles; express and review investor interest; support conversations and notifications; manage startup PDF pitch decks; and provide limited administration.

The current source covers account/profile data, discovery, saved profiles, investment request states, basic one-to-one text messaging, in-app notification records, local pitch-deck storage, and admin counts/list/verification. It does not implement investment transactions, payment processing, KYC, email OTP verification, mobile push delivery, or AI matching. No measured production baseline or business outcome was supplied.

## 1.3 System Analysis

| Role | Capabilities in source | Limits |
|---|---|---|
| Startup | Maintain profile, discover investors, save/remove profiles, receive and decide pending requests, manage PDF pitch deck, message, read notifications | Cannot express interest; discovery excludes same type |
| Investor | Maintain profile, discover startups, save/remove profiles, express interest, view requests, message, read notifications, download available startup decks | Cannot decide requests through request-update endpoint |
| Admin | Summary counts, list up to 100 users, mark a user verified | Admin provisioning is outside public registration |

### Functional requirements

| ID | Requirement | Implementation evidence |
|---|---|---|
| FR1 | Register Startup or Investor | Auth route validates data, creates user and initial profile |
| FR2 | Login and restore session | Login/current-user endpoints; token in Flutter Secure Storage |
| FR3 | Read/update own profile | Profile self routes |
| FR4 | Search opposite-role profiles | Profiles route with search/filter parameters |
| FR5 | Save/remove profile | Saved-profile PUT/DELETE |
| FR6 | Express and review interest | Investor-only create; startup request decision |
| FR7 | Start conversation/send messages | Conversation/message routes |
| FR8 | Read/mark notifications | Notification list/read/read-all routes |
| FR9 | Manage pitch deck | Authenticated PDF upload/download/delete |
| FR10 | Admin operations | Stats, user list, verify-user routes |

### Non-functional requirements and feasibility

| Area | Finding |
|---|---|
| Security | JWT bearer auth, role/ownership checks, bcryptjs cost 12; password hash hidden in ordinary queries |
| Validation | Registration, profile lengths/numbers/URL, message length, PDF signature/size |
| Availability | Client timeout is 45 seconds; major data screens have loading/error/empty states |
| Platform | Flutter Android; Android compile SDK 36 and Java 17 compile options; SDK min/target delegated to Flutter |
| Development | Dart constraint ^3.12.2, Node.js/npm, MongoDB |
| Scalability | No load test or scaling benchmark supplied |
| Technical feasibility | Client, backend, and MongoDB configuration exist; production readiness is not established |
| Operational feasibility | Device needs network access to API and database |
| Economic feasibility | No hosting quote or cost analysis supplied |

Release Gradle configuration uses debug signing and application ID com.example.inno. Production distribution needs product-owned signing/package identity and deployment configuration.

## 1.4 Architecture and Workflow

| Layer | Responsibility |
|---|---|
| Flutter Android client | Screens, navigation, API services, secure session storage |
| Node.js / Express | REST routes, auth/authorization middleware, validation and controllers |
| MongoDB / Mongoose | Documents, schemas, indexes and persistence |
| Local file store | Pitch-deck PDFs on backend host |

Client base URL comes from API_BASE_URL; defaults are Android emulator http://10.0.2.2:8081/api and localhost on desktop/web. Backend loads backend/.env, validates selected database, connects MongoDB and starts API. URI must select innovestia_app; on Windows code opens the existing on-disk casing Innovestia_app. The separate database called innovestia is not the application database.

Workflow: splash restores session; user registers/logs in; backend validates and issues JWT; Flutter stores token/user; protected requests include Bearer token; backend checks role and persists records; logout clears local session. Server logout does not revoke a copied JWT before expiry.

# 2. Technology Stack

| Technology | Purpose |
|---|---|
| Flutter / Dart | Android client UI and application logic |
| Material widgets | Forms, navigation, lists, dialogs, theme |
| http | REST JSON and binary PDF transfer |
| flutter_secure_storage | Local token and serialized user |
| file_picker | Select PDF and save downloaded PDF |
| Node.js / Express | Backend runtime and HTTP API |
| MongoDB / Mongoose | Document database and object modeling |
| jsonwebtoken | Signed bearer sessions; expiry defaults to seven days |
| bcryptjs | Password hashing/comparison, cost 12 |
| express-rate-limit | API and auth throttling |
| dotenv / cors | Environment configuration and origin handling |

Package manifests show no payment, analytics, email, or push SDK. README mentions configuring Resend, but no mail sender or OTP route/controller was found. Pitch decks use local filesystem storage; remote object storage is not implemented.

# 3. Modules and Screen Documentation

## 3.1 Screen Inventory

| Screen | Purpose and interaction | API/data |
|---|---|---|
| Splash | Brief brand display; route by restored session | AuthService session restore |
| Welcome | Navigate to login/registration | Navigation |
| Login | Email/password and role dashboard routing | POST auth/login |
| Registration | Name, email, phone, password, Startup/Investor role | POST auth/register |
| Dashboard Home | Role summary, quick actions, recent messages/activity | dashboard, conversations, notifications |
| Discover | Search opposite-role profiles, details, save/remove, investor interest | profiles, saved profiles, interests |
| Profile detail | Description/pitch metadata and eligible deck download | pitch download |
| Requests | Review; Startup accepts/declines pending requests | investment requests |
| Messages | Search users, open/create conversation | chat users, conversations |
| Conversation | Read/send text; polls every five seconds | conversation messages |
| Notifications | Mark one/all read; route to request/conversation | notifications |
| Profile | Edit own profile; startup PDF actions | profile and pitch routes |
| Admin users | List up to 100 user accounts | admin users |

Loading, error, and empty states are reusable UI states rather than separate routes.

## 3.2 Module Behavior

Registration allows Startup/Investor only. Backend validates fields, normalizes email, hashes password, creates User and initial Profile, and returns JWT. No OTP screen exists. Login/register are limited to 10 attempts per 15 seconds; excess returns HTTP 429 and Retry-After 15, and Flutter displays a countdown. An expired token is rejected during session restoration.

Startups maintain name, location, industry, stage, description, website, funding values, preferences and pitch details. They discover investors, save/remove profiles, receive and decide pending interest requests, message and manage a PDF deck. The request schema includes WITHDRAWN, but update controller accepts only ACCEPTED or REJECTED.

Investors maintain a profile, discover startups, save/remove, express interest, view own requests, message and download available startup decks. Investor-only interest is checked in the UI and backend. Interest creates a request and notification for startup. Startup decision is restricted to owner/admin, pending state, and notifies investor.

Messaging searches eligible opposite-role users, creates/reuses a one-to-one conversation, polls every five seconds, records incoming messages as read, and sends non-empty text up to 4,000 characters. This is polling, not WebSocket real-time delivery. Notifications are in-app database records, not push notifications.

Profile screen edits fields and manages startup PDF. Server accepts application/pdf up to 10 MB, checks PDF signature and required title, writes one file per user to configured local directory, and saves metadata. Download requires authentication and allows owner or investor viewing a startup deck.

Admin stats returns user/startup/investor/pending counts. Admin users lists up to 100 newest without password hashes. Verify route sets isVerified true. A corresponding verification control was not confirmed in Flutter AdminUsersScreen. Analytics charts, audit logs, and broader moderation were not found.

## 3.3 Screenshots

No application screenshots were supplied or found in the project inventory. Add actual device/emulator captures before submission: Figure 3.1 Welcome/Login; 3.2 Registration; 3.3 Startup dashboard; 3.4 Investor dashboard; 3.5 Discovery/detail; 3.6 Requests; 3.7 Conversation/notifications; 3.8 Profile/pitch; 3.9 Admin dashboard/user list.

# 4. Database Design

MongoDB is accessed through Mongoose. Seven models represent collections; explicit collection-name overrides were not found.

## 4.1 ER Diagram

| Relationship | Cardinality and reference |
|---|---|
| User to Profile | One user to zero/one profile; Profile.user unique |
| User to SavedProfile | One owner to many saves; SavedProfile.profile references Profile |
| User to InvestmentRequest | User appears as startup or investor in many requests |
| User to Conversation | Many-to-many participants; API creates a two-user pair |
| Conversation to Message | One conversation to many messages |
| User to Message | One sender to many messages |
| User to Notification | One recipient to many notifications |

Diagram schematic: User → Profile; User → SavedProfile → Profile; Startup User + Investor User → InvestmentRequest; User ↔ Conversation → Message → Sender User; User → Notification. These are Mongoose references, not relational foreign keys. Cardinality reflects unique index/API behavior.

## 4.2 Actual Collection Schemas

| Collection | Fields and constraints |
|---|---|
| User | _id ObjectId; name String required/trim/max100; email String required/unique/lowercase/trim; phone optional String; passwordHash required String/select:false; role required enum STARTUP/INVESTOR/ADMIN; isVerified Boolean default false; resetHash String and resetExpiresAt Date optional; timestamps |
| Profile | _id; user ObjectId→User required unique; type required enum STARTUP/INVESTOR; name required trim max100; location/industry/businessStage optional String max120; description optional String max2000; website optional String max500; fundingRequired/fundingRaised/investmentRangeMin/investmentRangeMax optional Number; preferences String[]; pitch.url/filename/title/summary/description String, size Number, updatedAt Date; timestamps |
| SavedProfile | _id; owner ObjectId→User required; profile ObjectId→Profile required; unique compound owner+profile; timestamps |
| InvestmentRequest | _id; startup/investor ObjectId→User required; message optional String max1000; status enum PENDING/ACCEPTED/REJECTED/WITHDRAWN default PENDING; index startup+investor+status; timestamps |
| Conversation | _id; participants User ObjectId array; pairKey optional sparse unique String; lastMessageAt Date; index participants+lastMessageAt; timestamps |
| Message | _id; conversation ObjectId→Conversation required/indexed; sender ObjectId→User required; body required String max4000; readBy User ObjectId array; timestamps |
| Notification | _id; recipient ObjectId→User required/indexed; title/body required String; type optional String; readAt Date; data Mixed; timestamps |

Profile has compound index type+industry+location+businessStage. InvestmentRequest duplicate pending prevention is application logic, not a unique index. Funding fields have no defined currency. WITHDRAWN is schema-supported but unsupported by update controller.

# 5. API Documentation

Resource routes require Bearer JWT unless public. Admin endpoints also require ADMIN.

| Method | Endpoint | Purpose / authorization |
|---|---|---|
| GET | /health, /api/health | Health; public |
| POST | /api/auth/register | Register Startup/Investor; public, throttled |
| POST | /api/auth/login | Login; public, throttled |
| GET | /api/auth/me | Current user; JWT |
| POST | /api/auth/logout | 204; clears client only, JWT not revoked |
| GET | /api/dashboard | Role summary |
| GET | /api/profiles | Opposite-role profiles; q/type/industry/location/businessStage/limit |
| GET / PUT | /api/profiles/me | Read/upsert own profile |
| GET | /api/profiles/saved | List saved profiles |
| PUT / DELETE | /api/profiles/:profileId/saved | Save/remove profile |
| PUT / DELETE | /api/profiles/me/pitch-deck | Upload/delete startup PDF |
| GET | /api/profiles/:profileId/pitch-deck | Owner or investor viewing startup |
| POST | /api/startups/:startupId/interests | Create interest; Investor |
| GET | /api/investment-requests | List user's requests |
| PUT | /api/investment-requests/:id | Accept/reject pending; startup owner/Admin |
| GET | /api/chat/users | Search opposite-role users |
| POST | /api/conversations | Open/create; body userId |
| GET | /api/conversations | List conversations |
| GET / POST | /api/conversations/:id/messages | List/read or send; participant |
| GET | /api/notifications | List up to 100 |
| GET | /api/notifications/unread-count | Count unread |
| PUT | /api/notifications/read-all | Mark all read; 204 |
| PUT | /api/notifications/:id/read | Mark one read |
| GET | /api/admin/stats | Counts; ADMIN |
| GET | /api/admin/users | Up to 100 newest, password hash excluded; ADMIN |
| PUT | /api/admin/users/:id/verify | Set isVerified; ADMIN |

Registration fields: name, email, optional phone, password, role (STARTUP/INVESTOR). Success is HTTP 201 with data containing token and public user; login returns same shape with HTTP 200. Never use a live token as an example. Duplicate email returns 409; invalid fields/short password 422; invalid credentials 401; missing/expired auth 401; permission failure 403; auth throttle 429 and Retry-After 15. Errors generally have a JSON message field. Mongoose validation maps to 422, duplicate key to 409, unknown route to 404, and production 500 uses a generic message.

# 6. User Manual

These steps describe source-defined behavior; they do not claim that every flow was exercised on a physical device or production service.

## 6.1 Installation and Launch

1. Install a supplied APK or run through Flutter tooling.
2. Configure reachable API. Emulator default is http://10.0.2.2:8081/api; physical device needs LAN reachability or HTTPS.
3. Start backend and MongoDB for the app database.
4. Launch. Splash opens Welcome or restored dashboard.

Release currently uses debug signing; configure a release keystore before distribution.

## 6.2 Startup and Investor Steps

Registration: choose Create Account; enter name/email/phone/password; choose Startup or Investor; submit. Success creates account/profile and opens dashboard. OTP/email verification is not in the inspected flow.

Startup: edit profile; discover investors; save/remove profiles; review and accept/decline pending requests; use Messages; upload PDF with title (10 MB limit); read Alerts; logout from Profile.

Investor: edit profile; discover startups; save or Express Interest; view request status; download available pitch deck; message; read Alerts; logout.

Admin: sign in with operator-provisioned account; review summary and users. Server verification route exists, but client action was not confirmed; use an authorized admin client until UI support exists.

## 6.3 Troubleshooting

| Symptom | Checks |
|---|---|
| Cannot connect | Backend running, network reachable, correct API_BASE_URL and /api |
| 401/session expired | Sign in again |
| 429 on auth | Wait 15 seconds |
| Website rejected | Full HTTP/HTTPS URL |
| PDF rejected | Startup role, valid PDF signature, title, <=10 MB |
| Empty discovery | Clear query; ensure opposite-role profiles exist |
| Admin denied | Confirm ADMIN; public registration cannot create admin |

# 7. Testing and Verification

Existing tests are test/widget_test.dart and backend/test/auth-rate-limit.test.js. Latest available project verification recorded **12 Flutter tests passing** and **2 backend tests passing**. Coverage includes API URL/header, error preservation, 429 retry data, login/register cooldown UI, validation, role serialization/routing, auth throttle, and malformed website rejection before database writes. This does not establish full Android acceptance.

| ID | Scenario | Expected | Observed |
|---|---|---|---|
| T1 | API URL/header | Correct URL/header | Flutter test: Pass |
| T2 | API error/429 | Message/status/cooldown retained | Flutter test: Pass |
| T3 | Login cooldown | Button disabled then enabled | Widget test: Pass |
| T4 | Registration cooldown | Submit disabled during wait | Widget test: Pass |
| T5 | Validation/roles | Valid inputs and role mapping | Flutter tests: Pass |
| T6 | 11 auth attempts | 11th returns 429, Retry-After 15 | Node test: Pass |
| T7 | Malformed website | 422 before DB write | Node test: Pass |
| T8 | Live account persistence | User/profile/login work | Not verified end-to-end |
| T9 | Two-user request workflow | Persisted request and notifications | Not verified end-to-end |
| T10 | Two-user messaging | Participant/read state correct | Not verified end-to-end |
| T11 | PDF round trip | Upload/download/delete works | Not verified end-to-end |
| T12 | Physical release install | Main flows work on Android | Not verified acceptance run |

No tests were run to prepare this report. An APK build alone does not verify live API, workflow acceptance, production signing, or deployment.

# 8. Security and Validation

Passwords use bcryptjs cost 12. JWT expiry defaults to seven days. Public user objects omit password hash. Flutter Secure Storage holds token/user and API sends Bearer token. Logout clears local state, but there is no server denylist/revocation.

Authenticated routes require valid JWT. Admin routes require ADMIN; interest requires Investor; profile save prevents self/same-type; conversations require participant; pitch download allows owner or investor viewing startup; request decisions require startup owner/Admin and PENDING status.

Backend validates registration, profile text lengths, HTTP/HTTPS URLs, non-negative funding and range ordering. Messages must be non-empty and max 4,000. Pitch requires PDF signature/title and is limited to 10 MB. JSON limit is 1 MB. CORS uses configured origins and development loopback. Global rate limit is 300 per 15 minutes; auth is 10 per 15 seconds.

Limitations supported by source: local file storage depends on backend host; logout does not revoke JWT; release config uses debug signing and example ID; no OTP/mail, push provider, KYC, audit log, penetration-test result, or production hardening report was found. Secrets from backend/.env are not included.

# 9. Limitations and Future Scope

| Status | Findings |
|---|---|
| Implemented | Auth, role UI, profiles, discovery/search, saves, investor requests/decisions, polling chat, in-app notifications, local PDF management, admin summary/list/verification API |
| Tests pass | Selected client API/cooldown and backend throttle/profile validation |
| Not end-to-end verified | Live persistence, two-account request/chat, file round trip, deployed admin API, physical release |
| Partial | Admin API without confirmed verification UI; WITHDRAWN enum unsupported by update controller |
| Not found | OTP/email verification, password reset despite reset fields, push, WebSocket chat, payments, KYC, analytics suite, AI matching, remote storage |
| User input | Word template, personal/institution/guide details, approved declaration/acknowledgement, screenshots, deployment details |

Future enhancements: verified email and password reset; session revocation/refresh rotation; managed object storage and file scanning; push and event-driven messaging; admin controls/audit/pagination; explainable matching; investment pipeline analytics; integration/device tests; production signing, HTTPS, secrets, backups, monitoring, and privacy documentation. These are proposals, not current capabilities.

# 10. Conclusion

Innovestia is a full-stack prototype for startup-investor discovery and coordination. Flutter, Express, and MongoDB implement role accounts, profiles, saved profiles, interest requests, polling conversations, in-app notifications, startup PDFs, and limited admin operations. Source includes validation, access checks, password hashing, JWT, and rate limiting.

Boundaries remain important: OTP/email verification is not implemented, notifications are not push delivered, messaging polls, pitch files use local storage, and admin verification UI was not confirmed. Automated tests cover selected client/backend behavior; full live-user and device workflows remain unverified.

# References

1. Flutter documentation: https://docs.flutter.dev/
2. Dart documentation: https://dart.dev/
3. Node.js documentation: https://nodejs.org/docs/
4. Express documentation: https://expressjs.com/
5. MongoDB documentation: https://www.mongodb.com/docs/
6. Mongoose documentation: https://mongoosejs.com/docs/
7. JSON Web Token introduction: https://jwt.io/introduction
8. Project source: lib/, backend/src/, test/, backend/test/, pubspec.yaml, backend/package.json, README.md, Android Gradle and manifest configuration.

# Appendix A. Source Review Map

| Area | Source |
|---|---|
| App and routes | lib/main.dart, lib/app.dart, lib/core/routes/app_routes.dart |
| Auth/session | lib/screens/auth/, lib/services/auth_service.dart, lib/services/storage_service.dart |
| Dashboard/features | lib/screens/dashboard/dashboard_screen.dart, lib/screens/features/feature_screens.dart |
| API/validation | lib/services/api_service.dart, lib/core/utils/validators.dart, lib/core/constants/app_constants.dart |
| Backend | backend/server.js, backend/src/app.js, backend/src/middleware/, routes/, controllers/ |
| Database | backend/src/models/, backend/src/config/database.js |
| Tests/dependencies | test/widget_test.dart, backend/test/auth-rate-limit.test.js, manifests, README |

# Appendix B. Template and Review Note

No .docx template was present in the workspace, parent project folder, or supplied attachment; attachment contained task instructions only. This newly formatted report cannot preserve unavailable page layout, headers, footers, chapter numbering, or diagrams. It is a new file and does not overwrite a source document. Personal/institution details and screenshots are marked for completion.
