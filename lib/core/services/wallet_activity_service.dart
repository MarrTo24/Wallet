// Servicio de registro de actividad local del wallet.
// Persiste los últimos 50 eventos en FlutterSecureStorage.
// Se usa para mostrar el historial de actividad en la pantalla principal.
// Los eventos son locales y no se sincronizan con el servidor.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tipos de evento reconocidos por el wallet.
class WalletEventType {
  static const login             = 'login';
  static const logout            = 'logout';
  static const credentialReceived = 'credential_received';
  static const qrScanned         = 'qr_scanned';
  static const qrShared          = 'qr_shared';
  static const pinChanged        = 'pin_changed';
  static const pinVerified       = 'pin_verified';
  static const filesReceived     = 'files_received';
  static const enrollmentStarted = 'enrollment_started';
  static const enrollmentComplete = 'enrollment_complete';
  static const verificationOk    = 'verification_ok';
  static const verificationFail  = 'verification_fail';
}

/// Un evento de actividad del wallet.
class WalletEvent {
  /// Tipo de evento — uno de [WalletEventType].
  final String type;

  /// Descripción corta legible para el usuario.
  final String description;

  /// Detalle técnico opcional (ej. enrollment_id, credential_id).
  final String? detail;

  /// Momento en que ocurrió el evento (UTC).
  final DateTime timestamp;

  const WalletEvent({
    required this.type,
    required this.description,
    this.detail,
    required this.timestamp,
  });

  /// Construye un WalletEvent desde JSON almacenado.
  factory WalletEvent.fromJson(Map<String, dynamic> json) => WalletEvent(
        type: json['type'] as String,
        description: json['description'] as String,
        detail: json['detail'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  /// Serializa el evento a JSON para su almacenamiento.
  Map<String, dynamic> toJson() => {
        'type': type,
        'description': description,
        'detail': detail,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Icono representativo del tipo de evento.
  IconData get icon => switch (type) {
        WalletEventType.login             => Icons.login_rounded,
        WalletEventType.logout            => Icons.logout_rounded,
        WalletEventType.credentialReceived => Icons.verified_rounded,
        WalletEventType.qrScanned         => Icons.qr_code_scanner_rounded,
        WalletEventType.qrShared          => Icons.share_rounded,
        WalletEventType.pinChanged        => Icons.lock_reset_rounded,
        WalletEventType.pinVerified       => Icons.lock_open_rounded,
        WalletEventType.filesReceived     => Icons.folder_open_rounded,
        WalletEventType.enrollmentStarted => Icons.assignment_rounded,
        WalletEventType.enrollmentComplete => Icons.assignment_turned_in_rounded,
        WalletEventType.verificationOk    => Icons.check_circle_rounded,
        WalletEventType.verificationFail  => Icons.cancel_rounded,
        _                                 => Icons.history_rounded,
      };

  /// Color del icono según el tipo de evento.
  Color get iconColor => switch (type) {
        WalletEventType.credentialReceived ||
        WalletEventType.enrollmentComplete ||
        WalletEventType.verificationOk     => const Color(0xFF16A34A),
        WalletEventType.verificationFail   => const Color(0xFFDC2626),
        _                                  => const Color(0xFF0F62FE),
      };

  /// Tiempo transcurrido en formato legible (ej. "Hace 5 min").
  String get timeAgo {
    final diff = DateTime.now().toUtc().difference(timestamp.toUtc());
    if (diff.inSeconds < 60)  return 'Hace un momento';
    if (diff.inMinutes < 60)  return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24)    return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7)      return 'Hace ${diff.inDays}d';
    final d = timestamp.toLocal();
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}';
  }
}


class WalletActivityService {
  static const _storage  = FlutterSecureStorage();
  static const _key      = 'wallet_activity_log_v1';
  static const _maxEvents = 50;

  /// Agrega un nuevo evento al log local.
  ///
  /// Los eventos más antiguos se eliminan automáticamente cuando se
  /// supera el límite de [_maxEvents].
  Future<void> addEvent({
    required String type,
    required String description,
    String? detail,
  }) async {
    final events = await getRecentEvents(limit: _maxEvents);
    final newEvent = WalletEvent(
      type: type,
      description: description,
      detail: detail,
      timestamp: DateTime.now().toUtc(),
    );

    // Insertar al inicio para que el más reciente quede primero
    events.insert(0, newEvent);

    // Mantener solo los más recientes
    final trimmed = events.take(_maxEvents).toList();
    await _storage.write(
      key: _key,
      value: jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  /// Lee los eventos más recientes del log.
  ///
  /// [limit] controla cuántos eventos devolver (default 10).
  Future<List<WalletEvent>> getRecentEvents({int limit = 10}) async {
    try {
      final data = await _storage.read(key: _key);
      if (data == null || data.isEmpty) return [];

      final list = jsonDecode(data) as List;
      return list
          .map((e) => WalletEvent.fromJson(e as Map<String, dynamic>))
          .take(limit)
          .toList();
    } catch (_) {
      // Si el JSON está corrupto, devolvemos lista vacía
      return [];
    }
  }

  /// Borra todo el historial de actividad.
  Future<void> clearAll() => _storage.delete(key: _key);
}
