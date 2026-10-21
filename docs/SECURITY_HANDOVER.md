# Security and boarding change — 21 October 2026

Base: main commit 5d38f4dc7513b7c6b01e022a017ba7455c9fe7fb.
Work branch: fix/security-boarding-validation. Do not merge or deploy without review.

## Feature inventory from the actual source

| Area | Existing implementation | Change / remaining verification |
|---|---|---|
| Email/password login, persisted session | Firebase Auth, client auto-signup and profile creation | Sign-in only, activated profile required; server signup-blocking hook prepared |
| User roles | Agent, Supervisor, email-based Admin exception, self-role dropdown | Exception and self-role mutation removed; profiles provisioned via trusted Admin SDK only |
| Flight create/edit/list/close/reopen | Date, booked count, owner, participant array, night mode, operation times | Scoped queries, access rules, exact canonical flight number; legacy migration required |
| Flight delete | Client copy of logs to archive then recursive deletion | Soft delete retains audit and child records; retention cleanup still needs an approved policy |
| Invitations | Username/email lookup, pending list and acceptance | UID-bound deterministic invite IDs, atomic acceptance, pending bar and invite action made reachable |
| Camera | Embedded MobileScanner, default on, torch, PDF417/Aztec/QR/DataMatrix | Kept, Code128/Code39 added, serial scan guard and tab visibility guard; device testing required |
| Manual entry and OCR | Form, raw text and ML Kit image recognition | Explicit flight/date/origin required; no expected-flight fallback; list boarding routes through validation |
| BCBP | Fixed slices with heuristic repair, missing date accepted | Separate deterministic parser, hex-length segment walking, day/origin/number checks |
| Pre-BOARD / DFT Random | Choice dialog and success screens | Preserved green/blue; watchlist red before choice; wrong flight purple; duplicate grey |
| Watchlist | Per-flight CRUD, fuzzy matching and 500-row cap | Shared conservative name matcher, server reads without cap, fresh check before write; no cache claimed |
| Duplicate / infant | Non-atomic queries, infant bypass could overwrite same record | Transaction plus identity/seat locks; same record never bypassed; explicit infant link; infant offloaded before adult |
| Passenger lists/search | Status sections, name/seat search, manual actions | Preserved; manual boarding must verify card details |
| Staff and equipment | Per-flight CRUD, equipment type/model fields | Preserved; only owner/scoped Supervisor/Admin can modify |
| Operation times and reports | Automatic first/last boarding, close/reopen, CSV share | Preserved; boarding/audit/time updates atomic; CSV legacy formatting still needs review |
| Offline | Firestore caching plus boolean flag | Boolean no longer offered as a queue; boarding/offload require server/transaction success |
| Cloud Functions | Scaffold only | Identity signup blocker prepared, not deployed |
| Gate Panel / LP docx / OPR-FRM-0098 | No implemented integration found | Deferred |
| XLSX / email automation | Dependencies/scaffold do not prove operation | Deferred |

## Mandatory rollout sequence

1. Back up Firestore and Authentication; audit every existing role. Previously editable role values must not be assumed trustworthy. Build an explicit UID/role approval list.
2. On a trusted administrative workstation install `functions` dependencies and configure Google Application Default Credentials with the correct Firebase project. Provision reviewed existing Auth users with `node scripts/provision-user.cjs UID Agent` (or Supervisor/Admin). Accounts are created in the Firebase console / trusted Admin SDK only; credentials are not stored in this repository. Never embed service-account credentials in the APK.
3. Migrate each legacy flight: set `departureAirport: DLM` only after checking it, canonicalize `flightCode`, ensure valid `etdDateText`, preserve owner and participants. Normalize legacy seats (e.g. 032F to 32F) and inspect duplicate passenger rows before using new locks. Migrate pending invites to `flightId_inviteeUid` with an approved UID; unresolved/ambiguous usernames must be resolved by an operator. No live migration has been performed.
4. Run emulator and Flutter tests; review the draft PR and install the APK on test devices. Stop old clients before changing rules. Legacy direct boarding writes intentionally fail under the new rules.
5. Enable Firebase Authentication with Identity Platform if available; deploy and verify `blockClientSignup` before relying on signup prevention. It requires that product and may require billing. Alternatively evaluate Identity Platform's client signup-disable setting. Disable anonymous signup and restrict custom-token minting: these flows do not invoke blocking functions. Firestore activation/profile rules alone protect application data, but do not prevent creation of an Auth account in an unconfigured live project.
6. Deploy reviewed rules/indexes with `firebase deploy --only firestore:rules,firestore:indexes`; deploy the approved signup hook separately. Verify published rules using an unrelated real test account. This branch has not changed live Firebase configuration.
7. Publish/merge only after user approval. Keep an IAM-controlled rollback and restore plan; do not restore publicly accessible rules as an operational shortcut.

## Known boundaries / follow-up work

- Standard mandatory BCBP has day-of-year, not full year. The configured flight date supplies the year; an old card with the same Julian day cannot be ruled out without airline/DCS/issuance information. This parser is not digital-signature or airline manifest verification.
- Malformed or incomplete cards are rejected rather than repaired. Multi-leg cards require exactly one matching leg. Infant cards with blank/INF seats need an explicit adult/seat verification workflow; do not guess the adult.
- Watchlist matching removes exact titles, supports name order and spaces. Glued titles are considered only on the given-name side of `/`. Ambiguous names, transliteration beyond the explicit Turkish mappings, truncation, and fuzzy/phonetic candidates need human review and more airline samples. Shared PNR is not identity. PNR is not currently a separate positive-match route.
- Watchlist is refreshed from the server before selection and before boarding. Collection changes can still race a client transaction; central server-side watchlist adjudication/versioning is a follow-up. Rules enforce crew access, data invariants, status transitions and watchlist flag restrictions; they cannot prove that a modified authorized client parsed a genuine barcode or honestly computed the name match.
- Transactions serialize normal app clients and prevent repeat active boarding writes. Test concurrent scanning on two real devices, process termination, seat changes, and migration from existing duplicate records. These are separate from the rules unit suite.
- Boarding/offload are online-only until a durable operation queue, authorization expiry, watchlist freshness and conflict resolution design is implemented. No offline success is claimed.
- Soft deletion retains data. No automatic retention duration is invented. Approve a customer/legal retention period and implement a trusted recursive cleanup for pax, watchlist, locks, audit, exports and backups. Existing raw-barcode logs need an authorized cleanup; this patch stops new raw payload logging.
- Audit actor/time are server-rule checked and logs append-only; logs do not constitute a tamper-proof external security archive. Reports and existing equipment/staff screens still require full operational acceptance testing.

References: IATA BCBP Implementation Guide, seventh edition (mandatory field layout and variable-length data); Firebase Authentication blocking functions documentation; Firebase Firestore Rules emulator testing documentation.
