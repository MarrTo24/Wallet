// Pantalla de detalle de una credencial verificable.
// Muestra estado de vigencia, datos del titular y emisor, y una
// sección técnica colapsable con el JSON del VC completo.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/credential.dart';

class CredentialDetailScreen extends StatelessWidget {
  final Credential credential;
  const CredentialDetailScreen({super.key, required this.credential});

  @override
  Widget build(BuildContext context) {
    final expired = credential.expiresAt != null &&
        credential.expiresAt!.isBefore(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle de credencial'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/wallet'),
        ),
        actions: [
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.share_rounded),
            onPressed: () => context.push('/qr', extra: credential),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tarjeta de estado ─────────────────────────────────────────
            _StatusCard(credential: credential, expired: expired),
            const SizedBox(height: 16),

            // ── Datos del titular ─────────────────────────────────────────
            _InfoSection(
              title: 'Titular',
              icon: Icons.person_outline_rounded,
              rows: [
                _Row('Nombre',    credential.name),
                _Row('Nivel',     credential.level),
                _Row('ID',        credential.id),
              ],
            ),
            const SizedBox(height: 12),

            // ── Datos del emisor ──────────────────────────────────────────
            _InfoSection(
              title: 'Emisor',
              icon: Icons.verified_user_outlined,
              rows: [
                _Row('Emisor',    credential.issuer),
                _Row('Estado',    expired ? 'Expirada' : credential.status,
                    color: expired ? AppColors.error : AppColors.success),
                _Row('Emitida',   _fmt(credential.issuedAt)),
                if (credential.expiresAt != null)
                  _Row('Vence',   _fmt(credential.expiresAt!),
                      color: expired ? AppColors.error : null),
              ],
            ),
            const SizedBox(height: 12),

            // ── JSON técnico (colapsable) ──────────────────────────────────
            if (credential.verifiableCredential != null)
              _TechSection(vc: credential.verifiableCredential!),
            const SizedBox(height: 24),

            // ── Acciones ──────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/qr', extra: credential),
                icon: const Icon(Icons.qr_code_rounded),
                label: const Text('Compartir con QR firmado'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: credential.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID copiado al portapapeles.')),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copiar ID'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'N/A';
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }
}

// ── Modelos de datos locales ───────────────────────────────────────────────

/// Par etiqueta–valor para una fila de información.
class _Row {
  final String label;
  final String value;
  final Color? color;
  const _Row(this.label, this.value, {this.color});
}

// ── Widgets ────────────────────────────────────────────────────────────────

/// Tarjeta superior con icono, título, subtítulo y badge de estado.
class _StatusCard extends StatelessWidget {
  final Credential credential;
  final bool expired;
  const _StatusCard({required this.credential, required this.expired});

  @override
  Widget build(BuildContext context) {
    final bg     = expired ? AppColors.errorLight : AppColors.primaryLight;
    final ic     = expired ? AppColors.error      : AppColors.primary;
    final stColor = expired ? AppColors.error      : AppColors.success;
    final stText  = expired ? 'Expirada'           : credential.status;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.heroCard,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(credential.icon, color: ic, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(credential.title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(credential.subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: stColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.badge,
                    border: Border.all(color: stColor.withValues(alpha: 0.25)),
                  ),
                  child: Text(stText,
                      style: TextStyle(color: stColor, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección de información con título e icono.
class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_Row> rows;
  const _InfoSection({required this.title, required this.icon, required this.rows});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.primary, size: 17),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(r.label,
                        style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                  ),
                  Expanded(
                    child: Text(
                      r.value.isNotEmpty ? r.value : 'No disponible',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: r.color ?? AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      );
}

/// Sección técnica con el JSON del VC — colapsable.
class _TechSection extends StatefulWidget {
  final Map<String, dynamic> vc;
  const _TechSection({required this.vc});

  @override
  State<_TechSection> createState() => _TechSectionState();
}

class _TechSectionState extends State<_TechSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final subject = widget.vc['credentialSubject'] as Map<String, dynamic>? ?? {};
    final proof   = widget.vc['proof']             as Map<String, dynamic>? ?? {};

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Cabecera expandible
          InkWell(
            borderRadius: AppRadius.card,
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.code_rounded, color: AppColors.primary, size: 17),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Datos técnicos del VC',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textTertiary),
                ],
              ),
            ),
          ),

          // Contenido colapsable
          if (_open) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subject['enrollmentId'] != null)
                    _kv('Enrolamiento', subject['enrollmentId'].toString()),
                  if (subject['accessScopes'] is List)
                    _kv('Scopes', (subject['accessScopes'] as List).join(', ')),
                  if (proof['type'] != null)
                    _kv('Firma', proof['type'].toString()),
                  if (proof['created'] != null)
                    _kv('Firmado el', proof['created'].toString()),
                  const SizedBox(height: 10),
                  const Text('JSON completo:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary)),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        const JsonEncoder.withIndent('  ').convert(widget.vc),
                        style: const TextStyle(
                          fontSize: 10, fontFamily: 'monospace',
                          color: AppColors.textSecondary, height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Helper para renderizar una fila clave–valor técnica.
  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(k, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
          ],
        ),
      );
}
