import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/wallet_security_service.dart';

class PinScreen extends StatefulWidget {
  final String redirectTo;

  const PinScreen({
    super.key,
    this.redirectTo = '/wallet',
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String pin = '';
  bool _navigating = false;
  int _lockSecondsRemaining = 0;
  Timer? _lockTimer;

  final WalletSecurityService _securityService = WalletSecurityService();

  @override
  void initState() {
    super.initState();
    _checkPinSetup();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPinSetup() async {
    final hasPin = await _securityService.hasPin();
    if (!mounted) return;
    if (!hasPin) {
      context.go('/set-pin', extra: widget.redirectTo);
    }
  }

  void _safeGo(String location) {
    if (_navigating || !mounted) return;
    _navigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(location);
    });
  }

  void _startLockCountdown(int seconds) {
    _lockTimer?.cancel();
    setState(() => _lockSecondsRemaining = seconds);
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockSecondsRemaining--;
        if (_lockSecondsRemaining <= 0) {
          timer.cancel();
          _lockSecondsRemaining = 0;
        }
      });
    });
  }

  String _formatLock(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60} min';
    return '${seconds ~/ 3600} h';
  }

  Future<void> _authenticateWithBiometrics() async {
    final authenticated = await _securityService.authenticateWithBiometrics(
      reason: 'Confirma tu identidad para desbloquear el wallet',
    );
    if (!mounted) return;
    if (authenticated) {
      _safeGo(widget.redirectTo);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo autenticar con biometría. Usa tu PIN.'),
      ),
    );
  }

  void _addDigit(String digit) {
    if (_lockSecondsRemaining > 0 || pin.length >= 4) return;
    setState(() => pin += digit);
    if (pin.length == 4) _validatePin();
  }

  void _removeDigit() {
    if (pin.isNotEmpty) setState(() => pin = pin.substring(0, pin.length - 1));
  }

  Future<void> _validatePin() async {
    final result = await _securityService.verifyPin(pin);
    if (!mounted) return;

    switch (result.status) {
      case PinStatus.success:
        _safeGo(widget.redirectTo);

      case PinStatus.locked:
        setState(() => pin = '');
        _startLockCountdown(result.lockSeconds ?? 30);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Demasiados intentos. Bloqueado por ${_formatLock(result.lockSeconds ?? 30)}.',
            ),
          ),
        );

      case PinStatus.wrongPin:
        setState(() => pin = '');
        final left = result.attemptsLeft;
        final msg = left != null
            ? 'PIN incorrecto. ${left == 1 ? '1 intento restante' : '$left intentos restantes'} antes del bloqueo.'
            : 'PIN incorrecto.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Widget _buildDot(bool filled) {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? Colors.black : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildKey(String value) {
    return GestureDetector(
      onTap: () => _addDigit(value),
      child: Container(
        alignment: Alignment.center,
        child: Text(
          value,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lockSecondsRemaining > 0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(
                locked ? Icons.lock_clock : Icons.lock_rounded,
                size: 54,
                color: locked ? Colors.red.shade400 : const Color(0xFF0F62FE),
              ),
              const SizedBox(height: 20),
              Text(
                locked ? 'Wallet bloqueado' : 'Wallet bloqueado',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (locked)
                Text(
                  'Demasiados intentos fallidos.\nIntenta de nuevo en ${_formatLock(_lockSecondsRemaining)}.',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                )
              else
                const Text(
                  'Usa biometría o PIN para acceder a tus credenciales.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              if (!locked)
                TextButton.icon(
                  onPressed: _authenticateWithBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Usar biometría'),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => _buildDot(i < pin.length)),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: AbsorbPointer(
                  absorbing: locked,
                  child: Opacity(
                    opacity: locked ? 0.3 : 1.0,
                    child: GridView.count(
                      crossAxisCount: 3,
                      children: [
                        ...List.generate(
                          9,
                          (i) => _buildKey((i + 1).toString()),
                        ),
                        const SizedBox(),
                        _buildKey('0'),
                        GestureDetector(
                          onTap: _removeDigit,
                          child: const Icon(Icons.backspace_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
