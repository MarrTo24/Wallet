# identity_wallet_mvp

wallet project

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Step 2 - Crypto identity

This version adds a wallet identity based on an Ed25519 key pair stored with `flutter_secure_storage`.

What changed:
- The wallet creates or reuses a local Ed25519 key pair.
- The public key is converted into a `did:key` identifier for the holder.
- The Verifiable Presentation QR is signed with Ed25519.
- The verifier checks the signature and confirms that the holder DID matches the signing public key.

Important: issuer-side credential proof is still a demo proof. The next step is to move issuer signing to a backend service and validate issuer trust.

## Professional Architecture for an Identity Wallet

This section proposes a production-ready architecture for evolving this MVP into a secure and scalable identity wallet.

### 1) Architecture principles

- Security by design: keys never leave secure hardware/storage when possible.
- Privacy first: selective disclosure and minimal data sharing by default.
- Standards-based: align with W3C DID/VC and OpenID for Verifiable Presentations (OID4VP).
- Offline-capable core: credential storage and proof generation should work without network.
- Modular codebase: isolate crypto, credential logic, transport, and UI layers.

### 2) Recommended Flutter project structure

```text
lib/
  app/
    app.dart
    router.dart
    di/
      service_locator.dart
  core/
    errors/
    logging/
    config/
    security/
      secure_storage_service.dart
      biometric_gate.dart
    crypto/
      key_manager.dart
      signer.dart
      verifier.dart
  features/
    auth/
    identity/
      domain/
        entities/
          did_document.dart
          key_pair_ref.dart
        repositories/
          identity_repository.dart
        usecases/
          create_holder_identity.dart
          rotate_keys.dart
      data/
        datasources/
          local_identity_datasource.dart
        repositories/
          identity_repository_impl.dart
    credentials/
      domain/
        entities/
          verifiable_credential.dart
          presentation_definition.dart
        usecases/
          store_credential.dart
          build_presentation.dart
          verify_credential_chain.dart
      data/
        datasources/
          local_credential_datasource.dart
          remote_issuer_datasource.dart
    presentation/
      ui/
      state/
  shared/
    widgets/
    utils/
```

### 3) Layer responsibilities

- Presentation layer: screens, state management, UX flows, QR interactions.
- Domain layer: business rules (issue, store, select, present, verify credentials).
- Data layer: persistence, remote APIs, DID resolution, revocation checks.
- Core layer: cryptography, secure storage, error handling, logging, configuration.

### 4) Identity and key management model

- Use one master holder identity (DID) per wallet profile.
- Store private keys only in secure storage (and migrate to platform keystore/secure enclave where feasible).
- Support key rotation with key versioning and DID document update strategy.
- Maintain key metadata: algorithm, creation date, status, fingerprint.

### 5) Credential lifecycle

- Issuance: receive VC from issuer backend over secure channel.
- Validation on receipt:
  - issuer signature verification
  - expiration check
  - schema/type validation
  - optional revocation status check
- Storage: encrypted at rest with indexed metadata for fast lookup.
- Presentation:
  - holder consent
  - selective claim disclosure (when format allows)
  - proof generation and signing
- Verification feedback: display clear pass/fail reasons to user.

### 6) Security controls (minimum baseline)

- App lock with biometrics/PIN and inactivity timeout.
- Jailbreak/root detection policy (warn, limit, or block sensitive actions).
- Clipboard protection and screenshot redaction for sensitive screens.
- Certificate pinning for issuer/verifier APIs.
- Threat modeling and periodic security review.
- Audit trail without storing sensitive claim values in logs.

### 7) Interoperability and standards roadmap

- DID methods:
  - current: `did:key` for local/self-contained identity
  - next: `did:web` and/or ecosystem-specific DID method as needed
- VC formats:
  - JSON-LD VC (existing ecosystem compatibility)
  - JWT VC / SD-JWT VC for selective disclosure scenarios
- Protocols:
  - OID4VCI for issuance
  - OID4VP / SIOP v2 for presentation

### 8) State management and dependency injection

- Use Riverpod or Bloc consistently across the app.
- Keep use cases framework-agnostic.
- Inject repositories/services through a centralized DI container.
- Add environment configs (`dev`, `staging`, `prod`) with strict separation.

### 9) Testing strategy

- Unit tests:
  - crypto wrappers
  - use cases
  - DID/VC parsing and validation rules
- Integration tests:
  - issuance flow end-to-end with mocked backend
  - presentation and verification flow
- Security tests:
  - tampered VC payload
  - invalid signature
  - expired/revoked credentials
- Golden/UI tests for critical screens.

### 10) CI/CD and quality gates

- Required pipeline steps:
  - `flutter analyze`
  - `flutter test`
  - format checks
  - dependency vulnerability scan
- Enforce minimum test coverage threshold.
- Signed builds and artifact integrity checks.
- Versioned release notes with migration steps for credential schema changes.

### 11) Backend responsibilities (for production)

- Issuer backend signs credentials with managed keys (HSM/KMS preferred).
- Trust registry integration for issuer verification.
- Revocation/status endpoints (StatusList2021 or equivalent).
- Key rotation policies and incident response playbooks.

### 12) Suggested implementation phases

1. Stabilize local architecture (layers, DI, state management, tests).
2. Move issuer proof/signing to backend and validate issuer trust chain.
3. Add revocation/status checks and stronger verification UX.
4. Implement interoperability protocols (OID4VCI/OID4VP).
5. Harden security controls and complete external security review.
