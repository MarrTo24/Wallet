import 'dart:convert';

import '../../models/credential.dart';
import 'crypto_identity_service.dart';
import 'trust_registry_service.dart';

class VerifiableCredentialService {
  static const String issuerDid = 'did:example:issuer:identity-wallet-mvp';

  final CryptoIdentityService _cryptoIdentityService;
  final TrustRegistryService _trustRegistryService;

  VerifiableCredentialService({
    CryptoIdentityService? cryptoIdentityService,
    TrustRegistryService? trustRegistryService,
  }) : _cryptoIdentityService =
           cryptoIdentityService ?? CryptoIdentityService(),
       _trustRegistryService = trustRegistryService ?? TrustRegistryService();

  Future<Map<String, dynamic>> buildPresentation(Credential credential) async {
    final identity = await _cryptoIdentityService.getOrCreateIdentity();
    final verifiableCredential =
        credential.verifiableCredential ??
        _buildDemoVerifiableCredential(credential, identity.did);

    final presentationWithoutProof = {
      '@context': ['https://www.w3.org/2018/credentials/v1'],
      'type': ['VerifiablePresentation'],
      'holder': identity.did,
      'verifiableCredential': [verifiableCredential],
    };

    final proofValue = await _cryptoIdentityService.signPayload(
      presentationWithoutProof,
    );

    return {
      ...presentationWithoutProof,
      'proof': {
        'type': 'Ed25519Signature2020',
        'created': DateTime.now().toUtc().toIso8601String(),
        'verificationMethod': '${identity.did}#keys-1',
        'proofPurpose': 'authentication',
        'publicKeyBase64Url': identity.publicKey,
        'proofValue': proofValue,
      },
    };
  }

  Future<String> buildPresentationQrPayload(Credential credential) async {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(await buildPresentation(credential));
  }

  Future<VerificationResult> verifyPresentationPayload(String payload) async {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return const VerificationResult.invalid(
          'El QR no contiene un objeto JSON.',
        );
      }

      final types = _stringList(decoded['type']);
      if (!types.contains('VerifiablePresentation')) {
        return const VerificationResult.invalid(
          'El QR no contiene una presentacion verificable.',
        );
      }

      final presentationProof = decoded['proof'];
      if (presentationProof is! Map<String, dynamic>) {
        return const VerificationResult.invalid(
          'La presentacion no incluye firma criptografica del holder.',
        );
      }

      if (presentationProof['type'] != 'Ed25519Signature2020') {
        return const VerificationResult.invalid(
          'La presentacion no usa firma Ed25519Signature2020.',
        );
      }

      final proofValue = presentationProof['proofValue']?.toString();
      final publicKey = presentationProof['publicKeyBase64Url']?.toString();
      if (proofValue == null ||
          proofValue.isEmpty ||
          publicKey == null ||
          publicKey.isEmpty) {
        return const VerificationResult.invalid(
          'La firma no incluye proofValue o llave publica.',
        );
      }

      final payloadToVerify = Map<String, dynamic>.from(decoded)
        ..remove('proof');
      final signatureIsValid = await _cryptoIdentityService.verifyPayload(
        payload: payloadToVerify,
        signature: proofValue,
        publicKey: publicKey,
      );

      if (!signatureIsValid) {
        return const VerificationResult.invalid(
          'La firma criptografica de la presentacion no es valida.',
        );
      }

      final holder = decoded['holder']?.toString() ?? '';
      final expectedDid = CryptoIdentityService.didKeyFromPublicKey(
        base64Url.decode(_normalizeBase64Url(publicKey)),
      );
      if (holder != expectedDid) {
        return const VerificationResult.invalid(
          'El holder DID no corresponde con la llave publica usada para firmar.',
        );
      }

      final credentials = decoded['verifiableCredential'];
      if (credentials is! List || credentials.isEmpty) {
        return const VerificationResult.invalid(
          'La presentacion no contiene credenciales verificables.',
        );
      }

      final credential = credentials.first;
      if (credential is! Map<String, dynamic>) {
        return const VerificationResult.invalid(
          'La credencial no tiene formato valido.',
        );
      }

      final credentialTypes = _stringList(credential['type']);
      final subject = credential['credentialSubject'];
      final credentialProof = credential['proof'];
      final issuanceDate = DateTime.tryParse(
        credential['issuanceDate']?.toString() ?? '',
      );
      final expirationDate = DateTime.tryParse(
        credential['expirationDate']?.toString() ?? '',
      );

      if (!credentialTypes.contains('VerifiableCredential')) {
        return const VerificationResult.invalid(
          'La credencial no declara el tipo VerifiableCredential.',
        );
      }

      if (credential['issuer'] == null ||
          credential['issuer'].toString().isEmpty) {
        return const VerificationResult.invalid(
          'La credencial no incluye emisor.',
        );
      }

      if (issuanceDate == null) {
        return const VerificationResult.invalid(
          'La fecha de emision no es valida.',
        );
      }

      if (expirationDate != null &&
          expirationDate.isBefore(DateTime.now().toUtc())) {
        return const VerificationResult.invalid('La credencial esta expirada.');
      }

      if (subject is! Map<String, dynamic> || subject['id'] == null) {
        return const VerificationResult.invalid(
          'La credencial no incluye sujeto identificable.',
        );
      }

      if (subject['id']?.toString() != holder) {
        return const VerificationResult.invalid(
          'El sujeto de la credencial no coincide con el holder de la presentacion.',
        );
      }

      if (credentialProof is! Map<String, dynamic> ||
          credentialProof['proofValue'] == null) {
        return const VerificationResult.invalid(
          'La credencial no incluye prueba de integridad del emisor.',
        );
      }

      final issuerProofVerification = await _verifyCredentialProof(credential);
      if (!issuerProofVerification.isValid) {
        return VerificationResult.invalid(issuerProofVerification.message);
      }

      final issuerDid = credential['issuer']?.toString() ?? 'No disponible';
      final trustedIssuer = _trustRegistryService.findTrustedIssuer(issuerDid);
      final checks = <VerificationCheck>[
        const VerificationCheck.pass(
          'Formato VP',
          'La presentacion declara VerifiablePresentation.',
        ),
        const VerificationCheck.pass(
          'Firma holder',
          'La firma Ed25519 de la presentacion es valida.',
        ),
        const VerificationCheck.pass(
          'DID holder',
          'El DID del holder corresponde con la llave publica.',
        ),
        const VerificationCheck.pass(
          'Formato VC',
          'La credencial declara VerifiableCredential.',
        ),
        VerificationCheck.pass(
          'Vigencia',
          expirationDate == null
              ? 'La credencial no declara expiracion.'
              : 'La credencial no esta expirada.',
        ),
        issuerProofVerification.check,
        trustedIssuer == null
            ? VerificationCheck.warning(
                'Emisor confiable',
                'El emisor no esta en la lista local de confianza.',
              )
            : VerificationCheck.pass(
                'Emisor confiable',
                'Emisor reconocido: ${trustedIssuer.name}.',
              ),
      ];

      return VerificationResult.valid(
        holder: holder,
        issuer: issuerDid,
        issuerName: trustedIssuer?.name ?? 'Emisor no registrado',
        issuerCategory: trustedIssuer?.category ?? 'No confiable',
        isTrustedIssuer: trustedIssuer != null,
        subjectName: subject['name']?.toString() ?? 'No disponible',
        assuranceLevel:
            subject['assuranceLevel']?.toString() ?? 'No disponible',
        credentialStatus:
            subject['credentialStatus']?.toString() ?? 'No disponible',
        credentialType: credentialTypes.join(', '),
        signatureType: presentationProof['type']?.toString() ?? 'No disponible',
        checks: checks,
      );
    } catch (error) {
      return VerificationResult.invalid('No se pudo leer el QR: $error');
    }
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is String) {
      return [value];
    }
    return const [];
  }

  static String _credentialTypeName(String type) {
    switch (type) {
      case 'work':
        return 'EmployeeCredential';
      case 'home':
        return 'AddressCredential';
      case 'membership':
        return 'MembershipCredential';
      default:
        return 'IdentityCredential';
    }
  }

  Map<String, dynamic> _buildDemoVerifiableCredential(
    Credential credential,
    String holderDid,
  ) {
    return {
      '@context': [
        'https://www.w3.org/2018/credentials/v1',
        'https://identity-wallet.example/contexts/identity/v1',
      ],
      'id': 'urn:uuid:${credential.id}',
      'type': ['VerifiableCredential', _credentialTypeName(credential.type)],
      'issuer': issuerDid,
      'issuanceDate': credential.issuedAt.toUtc().toIso8601String(),
      if (credential.expiresAt != null)
        'expirationDate': credential.expiresAt!.toUtc().toIso8601String(),
      'credentialSubject': {
        'id': holderDid,
        'name': credential.subjectName,
        'assuranceLevel': credential.assuranceLevel,
        'credentialStatus': credential.status,
      },
      'proof': {
        'type': 'DemoIssuerProof2026',
        'created': DateTime.now().toUtc().toIso8601String(),
        'verificationMethod': '$issuerDid#demo-key-1',
        'proofPurpose': 'assertionMethod',
        'proofValue': _demoProofValue(credential),
      },
    };
  }

  Future<_IssuerProofVerification> _verifyCredentialProof(
    Map<String, dynamic> credential,
  ) async {
    final proof = credential['proof'];
    if (proof is! Map<String, dynamic>) {
      return _IssuerProofVerification.fail(
        'La credencial no incluye proof del emisor.',
      );
    }

    final proofType = proof['type']?.toString();
    if (proofType == 'DemoIssuerProof2026') {
      return _IssuerProofVerification.warning(
        'La credencial usa una prueba demo del emisor.',
      );
    }

    if (proofType != 'Ed25519Signature2020') {
      return _IssuerProofVerification.fail(
        'La credencial usa un tipo de firma de emisor no soportado.',
      );
    }

    final proofValue = proof['proofValue']?.toString();
    final publicKey = proof['publicKeyBase64Url']?.toString();
    if (proofValue == null ||
        proofValue.isEmpty ||
        publicKey == null ||
        publicKey.isEmpty) {
      return _IssuerProofVerification.fail(
        'La firma del emisor no incluye proofValue o llave publica.',
      );
    }

    final issuerDid = credential['issuer']?.toString() ?? '';
    final expectedIssuerDid = CryptoIdentityService.didKeyFromPublicKey(
      base64Url.decode(_normalizeBase64Url(publicKey)),
    );
    if (issuerDid != expectedIssuerDid) {
      return _IssuerProofVerification.fail(
        'El DID del emisor no corresponde con la llave publica de la firma.',
      );
    }

    final payloadToVerify = Map<String, dynamic>.from(credential)
      ..remove('proof');
    final signatureIsValid = await _cryptoIdentityService.verifyPayload(
      payload: payloadToVerify,
      signature: proofValue,
      publicKey: publicKey,
    );

    if (!signatureIsValid) {
      return _IssuerProofVerification.fail(
        'La firma criptografica del emisor no es valida.',
      );
    }

    return _IssuerProofVerification.pass(
      'La firma Ed25519 del emisor es valida.',
    );
  }

  static String _demoProofValue(Credential credential) {
    final source =
        '${credential.id}|${credential.issuer}|${credential.subjectName}|${credential.issuedAt.toUtc().toIso8601String()}';
    return base64Url.encode(utf8.encode(source)).replaceAll('=', '');
  }

  static String _normalizeBase64Url(String value) {
    return value.padRight(value.length + ((4 - value.length % 4) % 4), '=');
  }
}

class _IssuerProofVerification {
  final bool isValid;
  final String message;
  final VerificationCheck check;

  const _IssuerProofVerification._({
    required this.isValid,
    required this.message,
    required this.check,
  });

  factory _IssuerProofVerification.pass(String message) {
    return _IssuerProofVerification._(
      isValid: true,
      message: message,
      check: VerificationCheck.pass('Firma emisor', message),
    );
  }

  factory _IssuerProofVerification.warning(String message) {
    return _IssuerProofVerification._(
      isValid: true,
      message: message,
      check: VerificationCheck.warning('Firma emisor', message),
    );
  }

  factory _IssuerProofVerification.fail(String message) {
    return _IssuerProofVerification._(
      isValid: false,
      message: message,
      check: VerificationCheck.fail('Firma emisor', message),
    );
  }
}

class VerificationResult {
  final bool isValid;
  final bool isTrustedIssuer;
  final String message;
  final String holder;
  final String issuer;
  final String issuerName;
  final String issuerCategory;
  final String subjectName;
  final String assuranceLevel;
  final String credentialStatus;
  final String credentialType;
  final String signatureType;
  final List<VerificationCheck> checks;

  const VerificationResult._({
    required this.isValid,
    required this.message,
    this.isTrustedIssuer = false,
    this.holder = 'No disponible',
    this.issuer = 'No disponible',
    this.issuerName = 'No disponible',
    this.issuerCategory = 'No disponible',
    this.subjectName = 'No disponible',
    this.assuranceLevel = 'No disponible',
    this.credentialStatus = 'No disponible',
    this.credentialType = 'No disponible',
    this.signatureType = 'No disponible',
    this.checks = const [],
  });

  const VerificationResult.valid({
    required String holder,
    required String issuer,
    required String issuerName,
    required String issuerCategory,
    required bool isTrustedIssuer,
    required String subjectName,
    required String assuranceLevel,
    required String credentialStatus,
    required String credentialType,
    required String signatureType,
    required List<VerificationCheck> checks,
  }) : this._(
         isValid: true,
         isTrustedIssuer: isTrustedIssuer,
         message: isTrustedIssuer
             ? 'Identidad verificada con firma valida y emisor confiable.'
             : 'Firma valida, pero el emisor no esta en la lista local de confianza.',
         holder: holder,
         issuer: issuer,
         issuerName: issuerName,
         issuerCategory: issuerCategory,
         subjectName: subjectName,
         assuranceLevel: assuranceLevel,
         credentialStatus: credentialStatus,
         credentialType: credentialType,
         signatureType: signatureType,
         checks: checks,
       );

  const VerificationResult.invalid(String message)
    : this._(
        isValid: false,
        message: message,
        checks: const [
          VerificationCheck.fail(
            'Verificacion',
            'La presentacion no supero las validaciones.',
          ),
        ],
      );
}

class VerificationCheck {
  final String title;
  final String detail;
  final VerificationCheckStatus status;

  const VerificationCheck._(this.title, this.detail, this.status);

  const VerificationCheck.pass(String title, String detail)
    : this._(title, detail, VerificationCheckStatus.pass);

  const VerificationCheck.warning(String title, String detail)
    : this._(title, detail, VerificationCheckStatus.warning);

  const VerificationCheck.fail(String title, String detail)
    : this._(title, detail, VerificationCheckStatus.fail);
}

enum VerificationCheckStatus { pass, warning, fail }
