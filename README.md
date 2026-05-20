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
