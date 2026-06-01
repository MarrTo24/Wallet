# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run the app
flutter run

# Build
flutter build apk           # Android
flutter build ios           # iOS

# Tests
flutter test                # All tests
flutter test test/path/to/test.dart   # Single test file

# Lint / analyze
flutter analyze
dart format lib/            # Format all Dart files
dart format --check lib/    # Check formatting without writing
```

## Architecture

**State management:** Riverpod (`flutter_riverpod`). All providers live in `lib/features/*/providers/`. The main credential state is `credentialsProvider` (a `StateNotifier<List<Credential>>`).

**Navigation:** GoRouter (`go_router`). All 11 routes are defined in `lib/app/router.dart`. Screens that need data (e.g., a `Credential` object) receive it via `context.extra` — see existing routes for the pattern.

**Layer structure (current):**
- `lib/core/services/` — all business logic (crypto, session, enrollment, VC verification, trust registry)
- `lib/features/<feature>/` — screens + feature-level providers
- `lib/models/` — data models (`Credential`)

The `AGENTS.md` file describes a target clean-architecture migration (domain/data/presentation layers) that has not yet been applied.

**Credential flow:**
1. Credentials are `Credential` model instances wrapping a raw W3C VC (`Map<String, dynamic>`).
2. `CredentialNotifier` persists the list to `FlutterSecureStorage` as JSON.
3. `VerifiableCredentialService` builds and verifies signed `VerifiablePresentation` objects for QR sharing.

**Cryptography:**
- Holder identity: Ed25519 key pair generated once, stored in `FlutterSecureStorage`, exposed as a `did:key` DID.
- Signing uses the `cryptography` package (`Ed25519().newKeyPairFromSeed()`).
- `CryptoIdentityService` owns key generation, DID derivation (multicodec + base58btc), and payload signing/verification.
- `TrustRegistryService` contains a hardcoded list of trusted issuer DIDs; production use requires a live registry endpoint.

**Authentication gates:**
- On cold start, `SplashScreen` checks `SessionService` and routes to `/pin` (if a session exists) or `/login`.
- `WalletSecurityService` handles PIN comparison and biometric auth via `local_auth`.

**Enrollment:**
- `WalletEnrollmentService` parses enrollment QR payloads (deep-link or JSON) into `WalletEnrollmentInvitation`.
- After parsing, `EnrollmentReviewScreen` presents the data for user confirmation before credential issuance.

## Key files

| File | Purpose |
|------|---------|
| `lib/app/router.dart` | All GoRouter route definitions |
| `lib/core/services/crypto_identity_service.dart` | Ed25519 key management & `did:key` generation |
| `lib/core/services/verifiable_credential_service.dart` | VP building & 8-step verification pipeline |
| `lib/core/services/session_service.dart` | Session persistence (name, email, cert/key files) |
| `lib/core/services/wallet_enrollment_service.dart` | Enrollment QR parsing and invitation model |
| `lib/core/services/trust_registry_service.dart` | Hardcoded trusted issuer registry |
| `lib/features/wallet/providers/credential_provider.dart` | Riverpod credential state + secure storage persistence |
| `lib/models/credential.dart` | `Credential` model with W3C VC serialization |

## Standards & protocols

This app targets **W3C Verifiable Credentials 1.0** and **W3C DID Core**. The `did:key` method is used for holder DIDs. `AGENTS.md` outlines a roadmap toward OID4VCI / OID4VP interoperability and SD-JWT support.
