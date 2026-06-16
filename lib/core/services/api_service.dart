// Servicio centralizado de HTTP para comunicarse con el portal backend.
// Almacena el JWT y la URL base en FlutterSecureStorage.
// Todos los métodos ajustan automáticamente localhost → 10.0.2.2 para
// el emulador Android y agregan el header Authorization cuando hay token.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Excepción específica del API con el mensaje de error del servidor.
class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static const _storage = FlutterSecureStorage();

  // ── Claves de almacenamiento seguro ────────────────────────────────────
  static const _baseUrlKey = 'portal_base_url';
  static const _tokenKey   = 'portal_jwt_token';
  static const _nameKey    = 'portal_user_name';
  static const _emailKeyS  = 'portal_user_email';

  // ── Persistencia de configuración ─────────────────────────────────────

  /// Guarda la URL base del portal (ej. http://192.168.1.85:8010).
  Future<void> setBaseUrl(String url) async {
    await _storage.write(key: _baseUrlKey, value: url.trimRight());
  }

  /// Lee la URL base guardada. Devuelve null si no está configurada.
  Future<String?> getBaseUrl() => _storage.read(key: _baseUrlKey);

  /// Verifica si hay una URL configurada y token activo.
  Future<bool> isConfigured() async {
    final url   = await getBaseUrl();
    final token = await getToken();
    return url != null && url.isNotEmpty && token != null && token.isNotEmpty;
  }

  // ── JWT ────────────────────────────────────────────────────────────────

  /// Guarda el JWT y los datos básicos del usuario tras login/register.
  Future<void> saveSession({
    required String token,
    required String name,
    required String email,
  }) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _nameKey,  value: name),
      _storage.write(key: _emailKeyS, value: email),
    ]);
  }

  /// Lee el JWT guardado.
  Future<String?> getToken() => _storage.read(key: _tokenKey);

  /// Lee el nombre del usuario autenticado en el portal.
  Future<String?> getPortalUserName() => _storage.read(key: _nameKey);

  /// Elimina el JWT y los datos de sesión del portal.
  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _nameKey),
      _storage.delete(key: _emailKeyS),
    ]);
  }

  // ── Métodos HTTP ───────────────────────────────────────────────────────

  /// Realiza un POST autenticado y devuelve el body como Map.
  ///
  /// Lanza [ApiException] si el servidor devuelve un status >= 400.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri     = await _buildUri(path);
    final headers = await _buildHeaders();

    final response = await http
        .post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 20));

    return _handleResponse(response);
  }

  /// Realiza un GET autenticado y devuelve el body como Map.
  Future<Map<String, dynamic>> get(String path) async {
    final uri     = await _buildUri(path);
    final headers = await _buildHeaders();

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));

    return _handleResponse(response);
  }

  /// Realiza un PUT autenticado y devuelve el body como Map.
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri     = await _buildUri(path);
    final headers = await _buildHeaders();

    final response = await http
        .put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 15));

    return _handleResponse(response);
  }

  // ── Helpers privados ───────────────────────────────────────────────────

  /// Construye la Uri completa ajustando localhost → 10.0.2.2 en emulador Android.
  Future<Uri> _buildUri(String path) async {
    final base = await getBaseUrl();
    if (base == null || base.isEmpty) {
      throw const ApiException('URL del portal no configurada.', 0);
    }
    final uri = Uri.parse('$base$path');

    // En emulador Android, localhost no resuelve al host de la PC
    if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      return uri.replace(host: '10.0.2.2');
    }
    return uri;
  }

  /// Construye los headers HTTP incluyendo el JWT si está disponible.
  Future<Map<String, String>> _buildHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Interpreta la respuesta HTTP y lanza [ApiException] si el status >= 400.
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.body.isEmpty) return {};

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Respuesta inesperada del servidor.', response.statusCode);
    }

    if (response.statusCode >= 400) {
      final detail = body['detail']?.toString() ?? 'Error ${response.statusCode}';
      throw ApiException(detail, response.statusCode);
    }

    return body;
  }
}
