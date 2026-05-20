import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/verifiable_credential_service.dart';

class VerificationResultScreen extends StatelessWidget {
  final String qrValue;

  const VerificationResultScreen({
    super.key,
    required this.qrValue,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VerificationResult>(
      future: VerifiableCredentialService().verifyPresentationPayload(qrValue),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final result = snapshot.data ?? VerificationResult.invalid('No se pudo verificar la presentacion.');
        final status = _statusFor(result);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Resultado de verificacion'),
            backgroundColor: const Color(0xFFF8FAFC),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/wallet'),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                CircleAvatar(
                  radius: 52,
                  backgroundColor: status.backgroundColor,
                  child: Icon(status.icon, color: status.iconColor, size: 54),
                ),
                const SizedBox(height: 22),
                Text(
                  status.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  result.message,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _TrustScoreCard(result: result),
                const SizedBox(height: 16),
                _InfoCard(
                  title: 'Validaciones tecnicas',
                  children: result.checks.map((check) => _CheckRow(check: check)).toList(),
                ),
                const SizedBox(height: 16),
                _InfoCard(
                  title: 'Datos verificados',
                  children: [
                    _InfoRow(label: 'Titular', value: result.subjectName),
                    _InfoRow(label: 'Holder DID', value: result.holder),
                    _InfoRow(label: 'Emisor DID', value: result.issuer),
                    _InfoRow(label: 'Emisor', value: result.issuerName),
                    _InfoRow(label: 'Categoria', value: result.issuerCategory),
                    _InfoRow(label: 'Tipo', value: result.credentialType),
                    _InfoRow(label: 'Estado', value: result.credentialStatus),
                    _InfoRow(label: 'Nivel', value: result.assuranceLevel),
                    _InfoRow(label: 'Firma', value: result.signatureType),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoCard(
                  title: 'Resumen del QR',
                  children: [
                    Text(
                      qrValue.length > 700 ? '${qrValue.substring(0, 700)}...' : qrValue,
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
                    onPressed: () => context.go('/wallet'),
                    child: const Text('Volver al wallet'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _VerificationStatus _statusFor(VerificationResult result) {
    if (!result.isValid) {
      return const _VerificationStatus(
        title: 'Identidad no valida',
        icon: Icons.error_outline_rounded,
        backgroundColor: Color(0xFFFEE2E2),
        iconColor: Color(0xFF991B1B),
      );
    }

    if (!result.isTrustedIssuer) {
      return const _VerificationStatus(
        title: 'Firma valida con riesgo',
        icon: Icons.warning_amber_rounded,
        backgroundColor: Color(0xFFFEF3C7),
        iconColor: Color(0xFF92400E),
      );
    }

    return const _VerificationStatus(
      title: 'Identidad verificada',
      icon: Icons.verified_rounded,
      backgroundColor: Color(0xFFDCFCE7),
      iconColor: Color(0xFF166534),
    );
  }
}

class _VerificationStatus {
  final String title;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const _VerificationStatus({
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });
}

class _TrustScoreCard extends StatelessWidget {
  final VerificationResult result;

  const _TrustScoreCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final label = !result.isValid
        ? 'Riesgo alto'
        : result.isTrustedIssuer
            ? 'Confianza alta'
            : 'Confianza media';
    final color = !result.isValid
        ? const Color(0xFF991B1B)
        : result.isTrustedIssuer
            ? const Color(0xFF166534)
            : const Color(0xFF92400E);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: color, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.isTrustedIssuer
                      ? 'Firma valida y emisor incluido en el registro local de confianza.'
                      : 'La firma puede ser valida, pero falta confianza del emisor.',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.children,
  });

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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final VerificationCheck check;

  const _CheckRow({required this.check});

  @override
  Widget build(BuildContext context) {
    final icon = switch (check.status) {
      VerificationCheckStatus.pass => Icons.check_circle_rounded,
      VerificationCheckStatus.warning => Icons.warning_amber_rounded,
      VerificationCheckStatus.fail => Icons.cancel_rounded,
    };
    final color = switch (check.status) {
      VerificationCheckStatus.pass => const Color(0xFF166534),
      VerificationCheckStatus.warning => const Color(0xFF92400E),
      VerificationCheckStatus.fail => const Color(0xFF991B1B),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  check.detail,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

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
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
