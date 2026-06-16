import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/session_service.dart';
import '../../core/services/wallet_activity_service.dart';
import '../../core/services/wallet_enrollment_service.dart';
import 'providers/credential_provider.dart';

class EnrollmentReviewScreen extends ConsumerStatefulWidget {
  final String qrValue;

  const EnrollmentReviewScreen({super.key, required this.qrValue});

  @override
  ConsumerState<EnrollmentReviewScreen> createState() =>
      _EnrollmentReviewScreenState();
}

class _EnrollmentReviewScreenState
    extends ConsumerState<EnrollmentReviewScreen> {
  final WalletEnrollmentService _enrollmentService = WalletEnrollmentService();
  final SessionService _sessionService = SessionService();
  final WalletActivityService _activity = WalletActivityService();
  late final Future<WalletEnrollmentResolveResult> _enrollmentFuture;
  bool _creating = false;
  String _backTarget = '/login';

  @override
  void initState() {
    super.initState();
    _enrollmentFuture = _enrollmentService.resolveQrPayload(widget.qrValue);
    _loadBackTarget();
  }

  Future<void> _loadBackTarget() async {
    final hasSession = await _sessionService.hasSession();
    if (!mounted) return;

    setState(() {
      _backTarget = hasSession ? '/wallet' : '/login';
    });
  }

  Future<void> _createAccount(WalletEnrollmentInvitation invitation) async {
    if (_creating) return;

    setState(() {
      _creating = true;
    });

    try {
      final account = await _enrollmentService.createWalletAccount(invitation);
      await ref.read(credentialsProvider.notifier).replaceCredentials([
        account.credential,
      ]);
      // Registrar evento de enrolamiento completado
      await _activity.addEvent(
        type: WalletEventType.enrollmentComplete,
        description: 'Credencial recibida de ${invitation.issuerLabel}',
        detail: invitation.enrollmentId,
      );
      if (!mounted) return;
      context.go('/pin', extra: '/wallet');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _creating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la cuenta: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WalletEnrollmentResolveResult>(
      future: _enrollmentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _EnrollmentErrorState(
            message:
                snapshot.error?.toString() ?? 'No se pudo leer el QR de alta.',
            rawQr: widget.qrValue,
            backTarget: _backTarget,
          );
        }

        return _EnrollmentReadyState(
          result: snapshot.data!,
          creating: _creating,
          backTarget: _backTarget,
          onCreateAccount: _createAccount,
        );
      },
    );
  }
}

class _EnrollmentReadyState extends StatelessWidget {
  final WalletEnrollmentResolveResult result;
  final bool creating;
  final String backTarget;
  final ValueChanged<WalletEnrollmentInvitation> onCreateAccount;

  const _EnrollmentReadyState({
    required this.result,
    required this.creating,
    required this.backTarget,
    required this.onCreateAccount,
  });

  @override
  Widget build(BuildContext context) {
    final invitation = result.invitation;
    final canIssue =
        invitation.issueEndpoints.isNotEmpty ||
        invitation.enrollmentUrl != null;
    final canRegisterDid =
        !invitation.didRegistrationRequired ||
        invitation.didRegistrationEndpoint != null ||
        invitation.autoRegisterOnComplete;
    final canCreate = canIssue && canRegisterDid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Alta con QR'),
        backgroundColor: const Color(0xFFF8FAFC),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(backTarget),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 34,
              backgroundColor: Color(0xFFEFF6FF),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFF0F62FE),
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Alta de identidad autosoberana',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'El QR viene del portal de enrolamiento. Al confirmar se registra tu DID, se completa el alta y se guarda la credencial firmada en el wallet.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            _PortalStatusCard(result: result),
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Persona',
              children: [
                _InfoRow(label: 'Nombre', value: invitation.holderName),
                _InfoRow(label: 'Correo', value: invitation.email),
                _InfoRow(label: 'Alias', value: invitation.alias),
                _InfoRow(label: 'Tipo', value: invitation.accountTypeLabel),
              ],
            ),
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Enrolamiento',
              children: [
                _InfoRow(label: 'ID', value: invitation.enrollmentId),
                _InfoRow(label: 'Emisor', value: invitation.issuerLabel),
                _InfoRow(label: 'Estado', value: invitation.accessStatus ?? ''),
                _InfoRow(
                  label: 'Expira',
                  value: _formatDate(invitation.expiresAt),
                ),
                _InfoRow(label: 'Curva', value: invitation.allowedCurve),
                _HashRow(
                  label: 'CER SHA-256',
                  value: invitation.certificateSha256,
                ),
                _HashRow(label: 'KEY SHA-256', value: invitation.keySha256),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: creating || !canCreate
                    ? null
                    : () => onCreateAccount(invitation),
                icon: creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_outlined),
                label: Text(
                  creating ? 'Completando alta...' : 'Completar alta en wallet',
                ),
              ),
            ),
            if (!canCreate) ...[
              const SizedBox(height: 10),
              const Text(
                'No se pudo obtener toda la informacion del portal. En telefono fisico genera el QR usando la IP de tu PC en lugar de localhost.',
                style: TextStyle(color: Color(0xFF92400E), height: 1.35),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: creating ? null : () => context.go(backTarget),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _PortalStatusCard extends StatelessWidget {
  final WalletEnrollmentResolveResult result;

  const _PortalStatusCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.syncedWithPortal
        ? const Color(0xFF166534)
        : const Color(0xFF92400E);
    final background = result.syncedWithPortal
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEF3C7);
    final icon = result.syncedWithPortal
        ? Icons.cloud_done_outlined
        : Icons.info_outline;
    final title = result.syncedWithPortal
        ? 'Conectado al portal'
        : 'Portal pendiente';
    final detail =
        result.warning ??
        (result.syncedWithPortal
            ? 'La invitacion se resolvio correctamente y esta lista para completar el alta.'
            : 'Falta consultar el portal para completar el alta con una credencial firmada.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(detail, style: TextStyle(color: color, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnrollmentErrorState extends StatelessWidget {
  final String message;
  final String rawQr;
  final String backTarget;

  const _EnrollmentErrorState({
    required this.message,
    required this.rawQr,
    required this.backTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('QR no valido'),
        backgroundColor: const Color(0xFFF8FAFC),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(backTarget),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFF991B1B),
              size: 58,
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Contenido escaneado',
              children: [
                Text(
                  rawQr.length > 700 ? '${rawQr.substring(0, 700)}...' : rawQr,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => context.go('/scan'),
                child: const Text('Escanear otro QR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'No disponible' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _HashRow extends StatelessWidget {
  final String label;
  final String value;

  const _HashRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final shortened = value.length > 18
        ? '${value.substring(0, 10)}...${value.substring(value.length - 8)}'
        : value;

    return _InfoRow(label: label, value: shortened);
  }
}
