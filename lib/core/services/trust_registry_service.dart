import 'api_service.dart';

class TrustedIssuer {
  final String did;
  final String name;
  final String category;

  const TrustedIssuer({
    required this.did,
    required this.name,
    required this.category,
  });
}

/// Servicio de registro de emisores de confianza.
///
/// Consulta `GET /api/trust-registry` en el portal y cachea el resultado
/// 10 minutos. Si el portal no está disponible (sin red, URL no configurada),
/// cae automáticamente al fallback local que solo incluye el emisor real.
class TrustRegistryService {
  final ApiService _api;

  List<TrustedIssuer>? _cached;
  DateTime? _cacheExpiry;
  static const _cacheTtl = Duration(minutes: 10);

  // Fallback local: solo el DID real del portal SeguriData.
  // Los DIDs de demo han sido eliminados intencionalmente.
  static const _localFallback = [
    TrustedIssuer(
      did: 'did:key:z6MkkKZgsxAbqyWGdBUonDQFyLqNZdBtx8BACwmSQJ7KLLMi',
      name: 'Portal SSI Issuer — SeguriData',
      category: 'Portal de enrolamiento',
    ),
  ];

  TrustRegistryService({ApiService? api}) : _api = api ?? ApiService();

  Future<List<TrustedIssuer>> _loadIssuers() async {
    final now = DateTime.now();
    if (_cached != null && _cacheExpiry != null && now.isBefore(_cacheExpiry!)) {
      return _cached!;
    }

    try {
      final response = await _api.get('/api/trust-registry');
      final rawList = response['issuers'] as List<dynamic>? ?? [];
      _cached = rawList
          .whereType<Map<String, dynamic>>()
          .where((e) => (e['did'] as String?)?.isNotEmpty == true)
          .map((e) => TrustedIssuer(
                did: e['did'] as String,
                name: e['name'] as String? ?? 'Emisor desconocido',
                category: e['category'] as String? ?? 'Emisor verificado',
              ))
          .toList();
      _cacheExpiry = now.add(_cacheTtl);
      return _cached!;
    } catch (_) {
      // Sin conexión o portal no configurado → fallback local
      return _localFallback;
    }
  }

  /// Devuelve el [TrustedIssuer] si el [did] está en el registro, o null si no.
  Future<TrustedIssuer?> findTrustedIssuer(String did) async {
    final issuers = await _loadIssuers();
    for (final issuer in issuers) {
      if (issuer.did == did) return issuer;
    }
    return null;
  }

  /// Devuelve true si el [did] pertenece a un emisor de confianza.
  Future<bool> isTrusted(String did) async =>
      (await findTrustedIssuer(did)) != null;

  /// Invalida la caché para forzar una nueva consulta al portal.
  void invalidateCache() {
    _cached = null;
    _cacheExpiry = null;
  }
}
