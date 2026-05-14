# GenesisApp Login, Session State, and Refresh Flow

Last updated: 2026-05-11
Scope: `genesis_flutter_android`

## 1. Entry points and auth gate

- App boot:
  - `lib/main.dart`
  - Initializes Firebase via `Firebase.initializeApp()`.
  - Reads local uid from `UserSession.readUid()`.
  - If no local uid exists, calls `GenesisApi().bindDevice()` to create/bind a guest uid.

- Auth gate for user features:
  - `lib/pages/app_shell_page.dart` -> `_ensureMeTabWithAuth()`
  - Triggered when entering the `Me` tab (`index == 4`).
  - Auth decision:
    - First: `GoogleSignInService.hasFirebaseSession()`
    - Second (if Firebase session missing): `GenesisApi.hasAuthenticatedSession()`
  - If not authenticated, shows `GoogleLoginSheet`.

## 2. Interactive login flow

- Login UI:
  - `lib/components/google_login_sheet.dart`
  - All UI copy is English.

- Google + Firebase sign in:
  - `lib/platform/google_sign_in_service.dart` -> `signInToFirebase()`
  - Steps:
    1. Validate platform and Firebase init.
    2. Read diagnostics from Android channel (`getSignInDiagnostics`) and resolve Web Client ID.
    3. `GoogleSignIn.instance.initialize(serverClientId: ...)`
    4. `GoogleSignIn.instance.authenticate(...)`
    5. Read Google `idToken`.
    6. `FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(...))`
    7. Build `GoogleFirebaseSession` (Google id token + Firebase token + uid/profile fields).

- Backend login:
  - `lib/network/genesis_api.dart` -> `loginWithGoogle({required String idToken})`
  - Calls `POST /api/auth/google`.
  - On success, persists backend uid via `UserSession.saveUid()`.

## 3. User state persistence

- Persistence layer:
  - Flutter side: `lib/platform/user_session.dart`
  - Android side: `android/app/src/main/kotlin/.../MainActivity.kt`
  - Stored in `SharedPreferences("genesis")` with key `uid`.

- Practical meaning:
  - Firebase keeps its own auth session (`FirebaseAuth.currentUser`).
  - App also stores uid locally for business APIs requiring `user_id`.
  - Cold start can continue with existing uid without forcing an immediate interactive login.

## 4. Expiration handling and automatic refresh

- Main backend session probe:
  - `lib/network/genesis_api.dart` -> `hasAuthenticatedSession({bool tryAutoRefresh = true})`
  - Calls `GET /api/auth/me/public-profile`.
  - Returns authenticated only when uid is non-empty and not `guest_*`.

- Auto refresh / silent reauth trigger:
  - When session check fails with `401` or `403`:
    1. `GoogleSignInService.refreshTokenOrSignInSilently()`
       - refreshes Firebase token if possible (`currentUser.getIdToken(true)`),
       - attempts lightweight Google auth restore (`attemptLightweightAuthentication()`),
       - re-signs into Firebase with refreshed Google id token.
    2. If silent restore succeeds, call backend `loginWithGoogle(idToken)`.
    3. Re-run `hasAuthenticatedSession(tryAutoRefresh: false)` once.

- Status code guard:
  - `lib/network/genesis_api.dart` -> `_isAuthFailureStatus(int? statusCode)`
  - Currently handles `401` and `403`.

## 5. Logout flow

- UI action:
  - `lib/pages/me/settings_page.dart` -> `_logout(...)`

- Behavior:
  1. `GoogleSignInService.signOutFirebase()` (Google sign-out + Firebase sign-out).
  2. `UserSession.clearUid()` (remove local uid from SharedPreferences).
  3. Return to caller and leave authenticated Me-state.

## 6. Current behavior boundaries

- Auth gate is centered on entering the `Me` tab.
- Automatic refresh/reauth is currently wired in backend session probing (`hasAuthenticatedSession`).
- There is no global "all API requests 401 interceptor + retry once" layer yet.
- If silent refresh fails, flow falls back to interactive Google login sheet.

## 7. Key files index

- `lib/main.dart`
- `lib/pages/app_shell_page.dart`
- `lib/components/google_login_sheet.dart`
- `lib/platform/google_sign_in_service.dart`
- `lib/platform/user_session.dart`
- `lib/network/genesis_api.dart`
- `android/app/src/main/kotlin/com/genesis/ai/genesis_flutter_android/MainActivity.kt`
