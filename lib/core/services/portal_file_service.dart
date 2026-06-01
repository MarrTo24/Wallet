import 'dart:convert';

import 'package:http/http.dart' as http;

/// Resultado de crear una sesión en el portal.
class PortalSession {
  final String sessionId;
  final String claimToken;
  final String portalUrl;
  final DateTime expiresAt;
  final bool emailSent;
  final String uploadUrl; // fallback si el email falla

  const PortalSession({
    required this.sessionId,
    required this.claimToken,
    required this.portalUrl,
    required this.expiresAt,
    required this.emailSent,
    required this.uploadUrl,
  });
}

/// Resultado de reclamar archivos del portal.
class PortalFileResult {
  final String cerFilename;
  final String cerBase64;
  final String keyFilename;
  final String keyBase64;

  const PortalFileResult({
    required this.cerFilename,
    required this.cerBase64,
    required this.keyFilename,
    required this.keyBase64,
  });
}

/// Estados posibles de una sesión en el portal.
enum PortalSessionStatus { waiting, filesReady, consumed, expired, unknown }

class PortalFileService {
  final http.Client _client;

  PortalFileService({http.Client? client}) : _client = client ?? http.Client();

  /// Llama al portal para crear una sesión y enviar el email al usuario.
  Future<PortalSession> createSession({
    required String portalUrl,
    required String email,
    required String holderName,
    required String alias,
  }) async {
    final uri = _resolveUri('$portalUrl/api/sessions');

    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'holder_name': holderName,
            'alias': alias,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 201 || body['ok'] != true) {
      throw Exception(
        body['detail']?.toString() ??
            'Error al crear sesión (HTTP ${response.statusCode}).',
      );
    }

    return PortalSession(
      sessionId: body['session_id'] as String,
      claimToken: body['claim_token'] as String? ?? '',
      portalUrl: portalUrl,
      expiresAt: DateTime.tryParse(
            body['expires_at']?.toString() ?? '',
          ) ??
          DateTime.now().add(const Duration(minutes: 15)),
      emailSent: body['email_sent'] as bool? ?? false,
      uploadUrl: body['upload_url'] as String? ?? '',
    );
  }

  /// Consulta el estado de la sesión (para mostrar feedback en tiempo real).
  Future<PortalSessionStatus> getStatus(PortalSession session) async {
    try {
      final uri = _resolveUri(
        '${session.portalUrl}/api/sessions/${session.sessionId}/status',
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseStatus(body['status']?.toString());
    } catch (_) {
      return PortalSessionStatus.unknown;
    }
  }

  /// Reclama los archivos del portal. Devuelve los archivos o lanza excepción.
  Future<PortalFileResult> claimFiles(PortalSession session) async {
    final uri = _resolveUri(
      '${session.portalUrl}/api/sessions/${session.sessionId}/claim',
    );

    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'claim_token': session.claimToken,
            'holder_did': '',
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 425) {
      throw const PortalFilesNotReadyException();
    }

    if (response.statusCode != 200 || body['ok'] != true) {
      throw Exception(
        body['detail']?.toString() ??
            'Error al reclamar archivos (HTTP ${response.statusCode}).',
      );
    }

    return PortalFileResult(
      cerFilename: body['cer_filename'] as String? ?? 'identity.cer',
      cerBase64: body['cer_base64'] as String? ?? '',
      keyFilename: body['key_filename'] as String? ?? 'identity.key',
      keyBase64: body['key_base64'] as String? ?? '',
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  static PortalSessionStatus _parseStatus(String? raw) {
    return switch (raw) {
      'waiting' => PortalSessionStatus.waiting,
      'files_ready' => PortalSessionStatus.filesReady,
      'consumed' => PortalSessionStatus.consumed,
      'expired' => PortalSessionStatus.expired,
      _ => PortalSessionStatus.unknown,
    };
  }

  /// Ajusta localhost → 10.0.2.2 para emulador Android.
  Uri _resolveUri(String url) {
    final uri = Uri.parse(url);
    if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      return uri.replace(host: '10.0.2.2');
    }
    return uri;
  }
}

class PortalFilesNotReadyException implements Exception {
  const PortalFilesNotReadyException();

  @override
  String toString() =>
      'Los archivos aún no han sido subidos al portal.';
}
