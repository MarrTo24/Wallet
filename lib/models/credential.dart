import 'package:flutter/material.dart';

class Credential {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String status;
  final String issuer;
  final String subjectName;
  final String assuranceLevel;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final IconData icon;
  final Map<String, dynamic>? verifiableCredential;

  Credential({
    required this.id,
    this.type = 'identity',
    required this.title,
    required this.subtitle,
    required this.status,
    required this.issuer,
    required String name,
    required String level,
    DateTime? issuedAt,
    this.expiresAt,
    IconData? icon,
    this.verifiableCredential,
  }) : subjectName = name,
       assuranceLevel = level,
       issuedAt = issuedAt ?? DateTime.now().toUtc(),
       icon = icon ?? _mapIcon(type);

  String get name => subjectName;
  String get level => assuranceLevel;

  factory Credential.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'identity';

    return Credential(
      id: json['id']?.toString() ?? '',
      type: type,
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      issuer: json['issuer']?.toString() ?? '',
      name: json['name']?.toString() ?? json['subjectName']?.toString() ?? '',
      level:
          json['level']?.toString() ?? json['assuranceLevel']?.toString() ?? '',
      issuedAt:
          DateTime.tryParse(json['issuedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
      icon: _mapIcon(type),
      verifiableCredential: json['verifiableCredential'] is Map
          ? Map<String, dynamic>.from(json['verifiableCredential'] as Map)
          : null,
    );
  }

  factory Credential.fromVerifiableCredential(
    Map<String, dynamic> verifiableCredential, {
    String? title,
    String? subtitle,
  }) {
    final subject = verifiableCredential['credentialSubject'] is Map
        ? Map<String, dynamic>.from(
            verifiableCredential['credentialSubject'] as Map,
          )
        : <String, dynamic>{};
    final types = verifiableCredential['type'] is List
        ? (verifiableCredential['type'] as List)
              .map((item) => item.toString())
              .toList()
        : <String>[];
    final credentialType = _typeFromVcTypes(types);
    final issuedAt = DateTime.tryParse(
      verifiableCredential['issuanceDate']?.toString() ?? '',
    );
    final expiresAt = DateTime.tryParse(
      verifiableCredential['expirationDate']?.toString() ?? '',
    );

    return Credential(
      id: verifiableCredential['id']?.toString() ?? '',
      type: credentialType,
      title: title ?? _titleFromType(credentialType),
      subtitle:
          subtitle ??
          '${subject['alias']?.toString() ?? 'Portal SSI'} - Credencial emitida',
      status: subject['credentialStatus']?.toString() ?? 'Activa',
      issuer: verifiableCredential['issuer']?.toString() ?? 'No disponible',
      name: subject['name']?.toString() ?? '',
      level: subject['assuranceLevel']?.toString() ?? 'Alto',
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      verifiableCredential: verifiableCredential,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'status': status,
      'issuer': issuer,
      'subjectName': subjectName,
      'assuranceLevel': assuranceLevel,
      'issuedAt': issuedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'verifiableCredential': verifiableCredential,
    };
  }

  static IconData _mapIcon(String? type) {
    switch (type) {
      case 'work':
        return Icons.business_center_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'membership':
        return Icons.card_membership_outlined;
      default:
        return Icons.badge_outlined;
    }
  }

  static String _typeFromVcTypes(List<String> types) {
    if (types.contains('EmployeeCredential')) return 'work';
    if (types.contains('AddressCredential')) return 'home';
    if (types.contains('MembershipCredential')) return 'membership';
    return 'identity';
  }

  static String _titleFromType(String type) {
    switch (type) {
      case 'work':
        return 'Credencial laboral';
      case 'home':
        return 'Comprobante de domicilio';
      case 'membership':
        return 'Membresia';
      default:
        return 'Identidad autosoberana';
    }
  }
}
