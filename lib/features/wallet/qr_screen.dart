import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/services/verifiable_credential_service.dart';
import '../../core/services/wallet_security_service.dart';
import '../../models/credential.dart';
import 'providers/credential_provider.dart';

class QrScreen extends ConsumerStatefulWidget {
  final Credential? initialCredential;

  const QrScreen({super.key, this.initialCredential});

  @override
  ConsumerState<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends ConsumerState<QrScreen> {
  final WalletSecurityService _securityService = WalletSecurityService();
  bool _authorized = false;
  bool _authenticating = true;
  String? _selectedCredentialId;
  String? _qrCredentialId;
  Future<String>? _qrPayloadFuture;

  @override
  void initState() {
    super.initState();
    _selectedCredentialId = widget.initialCredential?.id;
    _authorizeQrAccess();
  }

  Future<void> _authorizeQrAccess() async {
    if (!mounted) return;
    setState(() {
      _authenticating = true;
    });

    final authenticated = await _securityService.authenticateWithBiometrics(
      reason: 'Confirma tu identidad antes de compartir una credencial firmada',
    );

    if (!mounted) return;

    if (authenticated) {
      _unlockQr();
    } else {
      setState(() {
        _authorized = false;
        _authenticating = false;
      });
    }
  }

  void _unlockQr() {
    setState(() {
      _authorized = true;
      _authenticating = false;
    });
  }

  Future<void> _authorizeWithPin() async {
    final enteredPin = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: false,
      useSafeArea: true,
      builder: (_) => const _PinBottomSheet(),
    );

    if (!mounted || enteredPin == null) return;

    final validPin = await _securityService.verifyPin(enteredPin);
    if (!mounted) return;

    if (validPin) {
      _unlockQr();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN incorrecto')));
    }
  }

  List<Credential> _availableCredentials(List<Credential> credentials) {
    final byId = <String, Credential>{};

    for (final credential in credentials) {
      byId[credential.id] = credential;
    }

    final initialCredential = widget.initialCredential;
    if (initialCredential != null) {
      byId.putIfAbsent(initialCredential.id, () => initialCredential);
    }

    return byId.values.toList();
  }

  Credential? _selectedCredential(List<Credential> credentials) {
    if (credentials.isEmpty) return null;

    final selectedId = _selectedCredentialId;
    if (selectedId != null) {
      for (final credential in credentials) {
        if (credential.id == selectedId) return credential;
      }
    }

    for (final credential in credentials) {
      if (credential.type == 'identity' && credential.issuer == 'Portal SSI') {
        return credential;
      }
    }

    for (final credential in credentials) {
      if (credential.type == 'identity') return credential;
    }

    return credentials.first;
  }

  Future<String> _qrPayloadFor(Credential credential) {
    if (_qrPayloadFuture == null || _qrCredentialId != credential.id) {
      _qrCredentialId = credential.id;
      _qrPayloadFuture = VerifiableCredentialService()
          .buildPresentationQrPayload(credential);
    }

    return _qrPayloadFuture!;
  }

  void _selectCredential(String? credentialId) {
    if (credentialId == null || credentialId == _selectedCredentialId) return;

    setState(() {
      _selectedCredentialId = credentialId;
      _qrCredentialId = null;
      _qrPayloadFuture = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final credentials = _availableCredentials(ref.watch(credentialsProvider));
    final selectedCredential = _selectedCredential(credentials);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compartir identidad'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/wallet'),
        ),
      ),
      body: _authenticating
          ? const Center(child: CircularProgressIndicator())
          : !_authorized
          ? _LockedQrState(
              onUseBiometrics: _authorizeQrAccess,
              onUsePin: _authorizeWithPin,
            )
          : selectedCredential == null
          ? const _ErrorState(
              message: 'No hay credenciales disponibles para compartir.',
            )
          : FutureBuilder<String>(
              future: _qrPayloadFor(selectedCredential),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return _ErrorState(
                    message:
                        'No se pudo generar el QR firmado: ${snapshot.error}',
                  );
                }

                final qrData = snapshot.data!;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        'Presentacion verificable firmada',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Este QR se genera desde la credencial guardada en tu wallet despues de confirmar biometria o PIN.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (credentials.length > 1) ...[
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCredential.id,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Credencial a compartir',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: credentials.map((credential) {
                            return DropdownMenuItem(
                              value: credential.id,
                              child: Text(
                                credential.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _selectCredential,
                        ),
                      ],
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 240,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '${selectedCredential.subjectName} - ${selectedCredential.title}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Credencial ${selectedCredential.id} - Firma: Ed25519 - Acceso protegido por biometria/PIN.',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _PinBottomSheet extends StatefulWidget {
  const _PinBottomSheet();

  @override
  State<_PinBottomSheet> createState() => _PinBottomSheetState();
}

class _PinBottomSheetState extends State<_PinBottomSheet> {
  String _pin = '';
  bool _closing = false;

  void _addDigit(String digit) {
    if (_closing || _pin.length >= 4) return;
    setState(() {
      _pin += digit;
    });
    if (_pin.length == 4) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop(_pin);
      });
    }
  }

  void _removeDigit() {
    if (_closing || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Widget _dot(bool filled) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? Colors.black : Colors.grey.shade300,
      ),
    );
  }

  Widget _key(String value) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _addDigit(value),
      child: Center(
        child: Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Confirmar PIN',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ingresa el PIN del wallet para generar el QR firmado.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) => _dot(index < _pin.length)),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 300,
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              children: [
                ...List.generate(9, (index) => _key('${index + 1}')),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                _key('0'),
                IconButton(
                  onPressed: _removeDigit,
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedQrState extends StatelessWidget {
  final VoidCallback onUseBiometrics;
  final VoidCallback onUsePin;

  const _LockedQrState({required this.onUseBiometrics, required this.onUsePin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.privacy_tip_rounded,
              size: 64,
              color: Color(0xFF0F62FE),
            ),
            const SizedBox(height: 18),
            const Text(
              'Confirma antes de compartir',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Para proteger tu identidad, el QR firmado requiere biometria o PIN.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onUseBiometrics,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Usar biometria'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onUsePin,
                icon: const Icon(Icons.pin_rounded),
                label: const Text('Usar PIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF991B1B)),
        ),
      ),
    );
  }
}
