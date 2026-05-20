import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../models/credential.dart';
import 'crypto_identity_service.dart';
import 'session_service.dart';

class WalletEnrollmentInvitation {
  final String enrollmentId;
  final String alias;
  final String holderName;
  final String email;
  final String accountType;
  final String certificateSha256;
  final String keySha256;
  final String allowedCurve;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? offerNonce;
  final String? issuerDid;
  final String? issuerName;
  final String? accessStatus;
  final List<String> accessScopes;
  final bool didRegistrationRequired;
  final String? enrollmentUrl;
  final String? accessInvitationUrl;
  final String? completeSignupEndpoint;
  final String? credentialOfferUrl;
  final String? credentialRequestEndpoint;
  final String? didRegistrationEndpoint;
  final String? statusEndpoint;
  final bool autoRegisterOnComplete;

  const WalletEnrollmentInvitation({
    required this.enrollmentId,
    required this.alias,
    required this.holderName,
    required this.email,
    required this.accountType,
    required this.certificateSha256,
    required this.keySha256,
    required this.allowedCurve,
    required this.createdAt,
    this.expiresAt,
    this.offerNonce,
    this.issuerDid,
    this.issuerName,
    this.accessStatus,
    this.accessScopes = const [],
    this.didRegistrationRequired = false,
    this.enrollmentUrl,
    this.accessInvitationUrl,
    this.completeSignupEndpoint,
    this.credentialOfferUrl,
    this.credentialRequestEndpoint,
    this.didRegistrationEndpoint,
    this.statusEndpoint,
    this.autoRegisterOnComplete = false,
  });

  factory WalletEnrollmentInvitation.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString();
    final action =
        json['wallet_action']?.toString() ?? json['mobile_action']?.toString();

    if (type != WalletEnrollmentService.accessInvitationType &&
        type != WalletEnrollmentService.legacyEnrollmentType) {
      throw const FormatException('El QR no es una invitacion de wallet SSI.');
    }

    if (action != WalletEnrollmentService.accessWalletAction &&
        action != WalletEnrollmentService.legacyMobileAction) {
      throw const FormatException(
        'El QR no solicita registrar el wallet movil.',
      );
    }

    final credentialOffer = _asMap(json['credential_offer']);
    final claimsPreview = _asMap(json['claims_preview']);
    final certificate = _asMap(json['certificate']);
    final keyProof = _asMap(json['key_proof']);
    final issuer = _asMap(json['issuer']);
    final access = _asMap(json['access']);
    final account = _asMap(json['account']);
    final endpoints = _asMap(json['endpoints']);
    final didRegistration = _asMap(json['did_registration']);
    final privateKeyIncluded =
        _asBool(json['private_key_included_in_qr']) ||
        _asBool(keyProof['private_key_included_in_qr']);

    if (privateKeyIncluded) {
      throw const FormatException(
        'El QR incluye una llave privada. Por seguridad no se puede enrolar.',
      );
    }

    final enrollmentId = _firstString(json, const [
      'enrollment_id',
      'enrollmentId',
    ]);

    if (enrollmentId.isEmpty) {
      throw const FormatException(
        'El QR no contiene identificador de enrolamiento.',
      );
    }

    final allowedCurve = _firstString(json, const ['allowed_curve'], 'Ed25519');
    if (allowedCurve != 'Ed25519') {
      throw FormatException('Curva no soportada: $allowedCurve.');
    }

    final holderName = _firstStringFrom([
      claimsPreview['name'],
      account['name'],
      json['holder_name'],
      json['holderName'],
      json['name'],
    ]);
    final alias = _firstStringFrom([
      claimsPreview['alias'],
      account['alias'],
      json['alias'],
      holderName,
    ]);
    final didRegistrationRequired =
        _asBool(didRegistration['required']) ||
        _asBool(json['did_registration_required']);
    final autoRegisterOnComplete =
        _asBool(didRegistration['auto_register_on_complete']) ||
        _asBool(json['auto_register_on_complete']);

    return WalletEnrollmentInvitation(
      enrollmentId: enrollmentId,
      alias: alias,
      holderName: holderName,
      email: _firstStringFrom([
        claimsPreview['email'],
        account['email'],
        json['email'],
      ]),
      accountType: _firstStringFrom([
        claimsPreview['accountType'],
        claimsPreview['account_type'],
        account['account_type'],
        account['accountType'],
        json['account_type'],
        json['accountType'],
        'personal',
      ]),
      certificateSha256: _firstStringFrom([
        claimsPreview['certificateSha256'],
        claimsPreview['certificate_sha256'],
        json['certificate_sha256'],
        certificate['sha256'],
      ]),
      keySha256: _firstStringFrom([
        claimsPreview['keySha256'],
        claimsPreview['key_sha256'],
        json['key_sha256'],
        keyProof['sha256'],
      ]),
      allowedCurve: allowedCurve,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      expiresAt: DateTime.tryParse(
        _firstStringFrom([json['expires_at'], credentialOffer['expires_at']]),
      ),
      offerNonce: _nullableStringFrom([
        json['offer_nonce'],
        json['nonce'],
        credentialOffer['nonce'],
      ]),
      issuerDid: _nullableStringFrom([
        issuer['did'],
        json['issuer_did'],
        json['issuerDid'],
      ]),
      issuerName: _nullableStringFrom([
        issuer['name'],
        json['issuer_name'],
        json['issuerName'],
      ]),
      accessStatus: _nullableStringFrom([
        access['status'],
        json['access_status'],
        credentialOffer['status'],
      ]),
      accessScopes: _firstStringList([
        access['scopes'],
        json['access_scopes'],
        account['access_scopes'],
      ]),
      didRegistrationRequired: didRegistrationRequired,
      enrollmentUrl: _nullableString(json['enrollment_url']),
      accessInvitationUrl: _nullableStringFrom([
        json['access_invitation_url'],
        endpoints['access_invitation'],
      ]),
      completeSignupEndpoint: _nullableStringFrom([
        json['complete_signup_endpoint'],
        endpoints['complete_signup'],
      ]),
      credentialOfferUrl: _nullableStringFrom([
        json['credential_offer_url'],
        endpoints['credential_offer'],
      ]),
      credentialRequestEndpoint: _nullableStringFrom([
        json['credential_request_endpoint'],
        endpoints['credential_request'],
      ]),
      didRegistrationEndpoint: _nullableStringFrom([
        didRegistration['register_endpoint'],
        json['did_registration_endpoint'],
        endpoints['did_registration'],
      ]),
      statusEndpoint: _nullableStringFrom([
        json['status_endpoint'],
        endpoints['credential_status'],
      ]),
      autoRegisterOnComplete: autoRegisterOnComplete,
    );
  }

  String get shortEnrollmentId {
    if (enrollmentId.length <= 8) return enrollmentId;
    return enrollmentId.substring(0, 8);
  }

  String get accountTypeLabel {
    return accountType == 'business' ? 'Empresa' : 'Personal';
  }

  String get issuerLabel {
    return issuerName?.isNotEmpty == true ? issuerName! : 'Portal SSI';
  }

  bool get hasClaims {
    return holderName.isNotEmpty || email.isNotEmpty || alias.isNotEmpty;
  }

  String? get fetchEndpoint {
    return accessInvitationUrl ?? credentialOfferUrl ?? enrollmentUrl;
  }

  List<String> get issueEndpoints {
    return [
      completeSignupEndpoint,
      credentialRequestEndpoint,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'type': WalletEnrollmentService.accessInvitationType,
      'version': '2.0',
      'enrollment_id': enrollmentId,
      'offer_nonce': offerNonce,
      'issuer_did': issuerDid,
      'wallet_action': WalletEnrollmentService.accessWalletAction,
      'created_at': createdAt.toUtc().toIso8601String(),
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'allowed_curve': allowedCurve,
      'enrollment_url': enrollmentUrl,
      'access_invitation_url': accessInvitationUrl,
      'complete_signup_endpoint': completeSignupEndpoint,
      'credential_offer_url': credentialOfferUrl,
      'credential_request_endpoint': credentialRequestEndpoint,
      'status_endpoint': statusEndpoint,
      'claims_preview': {
        'name': holderName,
        'email': email,
        'alias': alias,
        'accountType': accountType,
        'certificateSha256': certificateSha256,
        'keySha256': keySha256,
      },
      'issuer': {'did': issuerDid, 'name': issuerName},
      'did_registration': {
        'required': didRegistrationRequired,
        'auto_register_on_complete': autoRegisterOnComplete,
        'register_endpoint': didRegistrationEndpoint,
      },
      'auto_register_on_complete': autoRegisterOnComplete,
      'access': {'status': accessStatus, 'scopes': accessScopes},
      'private_key_included_in_qr': false,
    };
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }

  static String _firstString(
    Map<String, dynamic> json,
    List<String> keys, [
    String fallback = '',
  ]) {
    for (final key in keys) {
      final value = _nullableString(json[key]);
      if (value != null) return value;
    }
    return fallback;
  }

  static String _firstStringFrom(List<Object?> values) {
    return _nullableStringFrom(values) ?? '';
  }

  static String? _nullableStringFrom(List<Object?> values) {
    for (final value in values) {
      final normalized = _nullableString(value);
      if (normalized != null) return normalized;
    }
    return null;
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static List<String> _firstStringList(List<Object?> values) {
    for (final value in values) {
      final normalized = _stringList(value);
      if (normalized.isNotEmpty) return normalized;
    }
    return const [];
  }
}

class WalletEnrollmentResolveResult {
  final WalletEnrollmentInvitation invitation;
  final bool syncedWithPortal;
  final String? warning;

  const WalletEnrollmentResolveResult({
    required this.invitation,
    required this.syncedWithPortal,
    this.warning,
  });
}

class WalletEnrollmentAccount {
  final WalletEnrollmentInvitation invitation;
  final CryptoIdentity identity;
  final Credential credential;

  const WalletEnrollmentAccount({
    required this.invitation,
    required this.identity,
    required this.credential,
  });
}

class WalletEnrollmentService {
  static const String accessInvitationType = 'ssi_wallet_access_invitation';
  static const String accessWalletAction =
      'scan_to_register_account_and_get_access';
  static const String legacyEnrollmentType = 'ssi_wallet_enrollment';
  static const String legacyMobileAction = 'scan_to_create_identity';
  static const _storage = FlutterSecureStorage();
  static const _savedEnrollmentKey = 'wallet_enrollment_record_v2';

  final http.Client _client;
  final SessionService _sessionService;
  final CryptoIdentityService _identityService;

  WalletEnrollmentService({
    http.Client? client,
    SessionService? sessionService,
    CryptoIdentityService? identityService,
  }) : _client = client ?? http.Client(),
       _sessionService = sessionService ?? SessionService(),
       _identityService = identityService ?? CryptoIdentityService();

  static bool looksLikeEnrollmentPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return false;

      final type = decoded['type']?.toString();
      final action =
          decoded['wallet_action']?.toString() ??
          decoded['mobile_action']?.toString();

      return type == accessInvitationType ||
          type == legacyEnrollmentType ||
          action == accessWalletAction ||
          action == legacyMobileAction ||
          decoded['access_invitation_url'] != null ||
          decoded['complete_signup_endpoint'] != null;
    } catch (_) {
      return false;
    }
  }

  Future<WalletEnrollmentResolveResult> resolveQrPayload(String payload) async {
    final invitation = WalletEnrollmentInvitation.fromJson(
      _decodePayload(payload),
    );
    final fetchEndpoint = invitation.fetchEndpoint;

    if (fetchEndpoint == null) {
      return WalletEnrollmentResolveResult(
        invitation: invitation,
        syncedWithPortal: false,
      );
    }

    try {
      final portalInvitation = await _fetchPortalInvitation(invitation);
      return WalletEnrollmentResolveResult(
        invitation: portalInvitation,
        syncedWithPortal: true,
      );
    } catch (error) {
      debugPrint('No se pudo sincronizar el enrolamiento: $error');
      return WalletEnrollmentResolveResult(
        invitation: invitation,
        syncedWithPortal: false,
        warning: _portalConnectionMessage(fetchEndpoint),
      );
    }
  }

  Future<WalletEnrollmentAccount> createWalletAccount(
    WalletEnrollmentInvitation invitation,
  ) async {
    final identity = await _identityService.getOrCreateIdentity();

    if (invitation.issueEndpoints.isEmpty && invitation.enrollmentUrl == null) {
      throw StateError(
        'La invitacion no incluye endpoint para completar el alta. Vuelve a generar el QR desde el portal.',
      );
    }

    await _registerDidIfNeeded(invitation, identity);
    final credential = await _issueCredential(invitation, identity);

    await _sessionService.saveSession(
      name: invitation.holderName.isNotEmpty
          ? invitation.holderName
          : invitation.alias,
      email: invitation.email,
    );
    await _saveEnrollment(invitation, identity);

    return WalletEnrollmentAccount(
      invitation: invitation,
      identity: identity,
      credential: credential,
    );
  }

  Credential buildCredential(WalletEnrollmentInvitation invitation) {
    return Credential(
      id: 'SSI-${invitation.shortEnrollmentId}',
      type: 'identity',
      title: 'Identidad autosoberana',
      subtitle: '${invitation.alias} - ${invitation.accountTypeLabel}',
      status: 'Activa',
      issuer: invitation.issuerLabel,
      name: invitation.holderName,
      level: 'Alto',
      issuedAt: invitation.createdAt,
    );
  }

  static Map<String, dynamic> _decodePayload(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      throw const FormatException('El QR no contiene un objeto JSON.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  Future<WalletEnrollmentInvitation> _fetchPortalInvitation(
    WalletEnrollmentInvitation invitation,
  ) async {
    Object? lastError;
    final endpoint = invitation.fetchEndpoint;

    if (endpoint == null) {
      throw StateError(
        'La invitacion no incluye URL para consultar el portal.',
      );
    }

    for (final uri in _candidateUris(endpoint)) {
      try {
        final response = await _client.get(uri);
        final decoded = _decodeResponseMap(response);

        if (response.statusCode != 200 || decoded['ok'] != true) {
          lastError =
              decoded['detail']?.toString() ?? 'HTTP ${response.statusCode}';
          continue;
        }

        final payload = _unwrapPortalPayload(decoded);
        return WalletEnrollmentInvitation.fromJson(
          _mergeInvitationPayload(invitation, payload),
        );
      } catch (error) {
        lastError = error;
      }
    }

    throw StateError(lastError?.toString() ?? 'Portal no disponible.');
  }

  Future<void> _registerDidIfNeeded(
    WalletEnrollmentInvitation invitation,
    CryptoIdentity identity,
  ) async {
    final endpoint = invitation.didRegistrationEndpoint;

    if (endpoint == null) {
      if (invitation.didRegistrationRequired &&
          !invitation.autoRegisterOnComplete) {
        throw StateError(
          'No se obtuvo el endpoint de registro DID. Revisa que el backend del portal este disponible.',
        );
      }
      return;
    }

    Object? lastError;
    for (final uri in _candidateUris(endpoint)) {
      try {
        final response = await _client.post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'holder_did': identity.did,
            'holder_public_key_base64url': identity.publicKey,
            'did_document': _buildDidDocument(identity),
          }),
        );
        final decoded = _decodeResponseMap(response);

        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            decoded['ok'] == true) {
          return;
        }

        lastError =
            decoded['detail']?.toString() ?? 'HTTP ${response.statusCode}';
      } catch (error) {
        lastError = error;
      }
    }

    throw StateError(
      'No se pudo registrar el DID en el portal. Detalle tecnico: $lastError',
    );
  }

  Future<Credential> _issueCredential(
    WalletEnrollmentInvitation invitation,
    CryptoIdentity identity,
  ) async {
    Object? lastError;

    for (final uri in _issueCredentialUris(invitation)) {
      try {
        final response = await _client.post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'holder_did': identity.did,
            'holder_public_key_base64url': identity.publicKey,
            'offer_nonce': invitation.offerNonce,
          }),
        );

        final decoded = _decodeResponseMap(response);
        if (response.statusCode != 200 || decoded['ok'] != true) {
          lastError =
              decoded['detail']?.toString() ??
              'HTTP ${response.statusCode}: ${response.body}';
          continue;
        }

        if (decoded['credential'] is! Map) {
          lastError = 'El portal no devolvio una credencial verificable.';
          continue;
        }

        final credential = Map<String, dynamic>.from(
          decoded['credential'] as Map,
        );
        await _validateIssuedCredential(credential, invitation, identity);

        return Credential.fromVerifiableCredential(
          credential,
          title: 'Identidad autosoberana',
          subtitle:
              '${invitation.alias} - Emitida por ${invitation.issuerLabel}',
        );
      } catch (error) {
        lastError = error;
      }
    }

    throw StateError(
      '${_portalConnectionMessage(invitation.completeSignupEndpoint ?? invitation.credentialRequestEndpoint ?? invitation.enrollmentUrl)} Detalle tecnico: $lastError',
    );
  }

  Future<void> _validateIssuedCredential(
    Map<String, dynamic> credential,
    WalletEnrollmentInvitation invitation,
    CryptoIdentity identity,
  ) async {
    final subject = credential['credentialSubject'];
    if (subject is! Map) {
      throw const FormatException('La credencial no incluye sujeto.');
    }

    if (subject['id']?.toString() != identity.did) {
      throw const FormatException(
        'La credencial emitida no corresponde al DID del wallet.',
      );
    }

    final subjectEnrollmentId = subject['enrollmentId']?.toString();
    if (subjectEnrollmentId != null &&
        subjectEnrollmentId != invitation.enrollmentId) {
      throw const FormatException(
        'La credencial emitida no corresponde al enrolamiento escaneado.',
      );
    }

    final issuerDid = credential['issuer']?.toString();
    if (invitation.issuerDid != null &&
        invitation.issuerDid!.isNotEmpty &&
        issuerDid != invitation.issuerDid) {
      throw const FormatException(
        'El emisor de la credencial no corresponde con el portal escaneado.',
      );
    }

    final proof = credential['proof'];
    if (proof is! Map || proof['type'] != 'Ed25519Signature2020') {
      throw const FormatException(
        'La credencial no incluye una firma Ed25519 del emisor.',
      );
    }

    final proofValue = proof['proofValue']?.toString();
    final publicKey = proof['publicKeyBase64Url']?.toString();
    if (proofValue == null ||
        proofValue.isEmpty ||
        publicKey == null ||
        publicKey.isEmpty) {
      throw const FormatException(
        'La firma del emisor no incluye proofValue o llave publica.',
      );
    }

    final expectedIssuerDid = CryptoIdentityService.didKeyFromPublicKey(
      base64Url.decode(_normalizeBase64Url(publicKey)),
    );
    if (issuerDid != expectedIssuerDid) {
      throw const FormatException(
        'El DID del emisor no corresponde con la llave publica de la firma.',
      );
    }

    final payloadToVerify = Map<String, dynamic>.from(credential)
      ..remove('proof');
    final signatureIsValid = await _identityService.verifyPayload(
      payload: payloadToVerify,
      signature: proofValue,
      publicKey: publicKey,
    );

    if (!signatureIsValid) {
      throw const FormatException(
        'La firma criptografica del emisor no es valida.',
      );
    }
  }

  Iterable<Uri> _candidateUris(String endpoint) sync* {
    final uri = Uri.tryParse(endpoint);
    if (uri == null) return;

    yield uri;

    if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      yield uri.replace(host: '10.0.2.2');
    }
  }

  Iterable<Uri> _issueCredentialUris(
    WalletEnrollmentInvitation invitation,
  ) sync* {
    final yielded = <String>{};

    for (final endpoint in invitation.issueEndpoints) {
      for (final uri in _candidateUris(endpoint)) {
        if (yielded.add(uri.toString())) yield uri;
      }
    }

    final legacyEnrollmentUrl = invitation.enrollmentUrl;
    if (legacyEnrollmentUrl == null) return;

    for (final uri in _candidateUris(legacyEnrollmentUrl)) {
      final issueUri = uri.replace(path: '${uri.path}/issue-credential');
      if (yielded.add(issueUri.toString())) yield issueUri;
    }
  }

  Map<String, dynamic> _decodeResponseMap(http.Response response) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic> _unwrapPortalPayload(Map<String, dynamic> decoded) {
    for (final key in const [
      'access_invitation',
      'credential_offer',
      'payload',
      'enrollment',
    ]) {
      final value = decoded[key];
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }

    return decoded;
  }

  Map<String, dynamic> _mergeInvitationPayload(
    WalletEnrollmentInvitation invitation,
    Map<String, dynamic> payload,
  ) {
    final merged = <String, dynamic>{...invitation.toJson(), ...payload};

    final currentClaims = WalletEnrollmentInvitation._asMap(
      invitation.toJson()['claims_preview'],
    );
    final incomingClaims = WalletEnrollmentInvitation._asMap(
      payload['claims_preview'],
    );
    final mergedClaims = <String, dynamic>{
      ...currentClaims,
      ...incomingClaims,
      if (payload['holder_name'] != null) 'name': payload['holder_name'],
      if (payload['email'] != null) 'email': payload['email'],
      if (payload['alias'] != null) 'alias': payload['alias'],
      if (payload['account_type'] != null)
        'accountType': payload['account_type'],
    };
    merged['claims_preview'] = mergedClaims;

    final certificate = WalletEnrollmentInvitation._asMap(
      payload['certificate'],
    );
    final keyProof = WalletEnrollmentInvitation._asMap(payload['key_proof']);
    if (certificate['sha256'] != null) {
      mergedClaims['certificateSha256'] = certificate['sha256'];
    }
    if (keyProof['sha256'] != null) {
      mergedClaims['keySha256'] = keyProof['sha256'];
    }

    final credentialOffer = WalletEnrollmentInvitation._asMap(
      payload['credential_offer'],
    );
    if (credentialOffer['nonce'] != null) {
      merged['offer_nonce'] = credentialOffer['nonce'];
    }
    if (credentialOffer['expires_at'] != null) {
      merged['expires_at'] = credentialOffer['expires_at'];
    }

    return Map<String, dynamic>.from(merged);
  }

  Map<String, dynamic> _buildDidDocument(CryptoIdentity identity) {
    final verificationMethod = '${identity.did}#keys-1';
    return {
      '@context': ['https://www.w3.org/ns/did/v1'],
      'id': identity.did,
      'verificationMethod': [
        {
          'id': verificationMethod,
          'type': 'Ed25519VerificationKey2020',
          'controller': identity.did,
          'publicKeyBase64Url': identity.publicKey,
        },
      ],
      'authentication': [verificationMethod],
      'assertionMethod': [verificationMethod],
    };
  }

  String _portalConnectionMessage(String? endpoint) {
    final uri = endpoint == null ? null : Uri.tryParse(endpoint);
    final host = uri?.host ?? '';
    final usingLocalhost =
        host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';

    if (usingLocalhost) {
      return 'No se pudo consultar el portal. En telefono fisico genera el QR con la IP de tu PC, por ejemplo http://192.168.1.50:8010, no con localhost.';
    }

    return 'No se pudo consultar el portal. Revisa que el backend este encendido, que el telefono y la PC esten en la misma red y que el puerto del backend este permitido.';
  }

  Future<void> _saveEnrollment(
    WalletEnrollmentInvitation invitation,
    CryptoIdentity identity,
  ) async {
    final record = {
      ...invitation.toJson(),
      'did': identity.did,
      'public_key': identity.publicKey,
      'identity_created_now': identity.createdNow,
    };

    await _storage.write(key: _savedEnrollmentKey, value: jsonEncode(record));
  }

  static String _normalizeBase64Url(String value) {
    return value.padRight(value.length + ((4 - value.length % 4) % 4), '=');
  }
}
