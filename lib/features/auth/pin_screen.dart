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
  final WalletSecurityService _securityService = WalletSecurityService();

  @override
  void initState() {
    super.initState();
    _securityService.ensureDemoPinExists();
  }

  void _safeGo(String location) {
    if (_navigating || !mounted) return;
    _navigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(location);
    });
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
    if (pin.length < 4) {
      setState(() {
        pin += digit;
      });

      if (pin.length == 4) {
        _validatePin();
      }
    }
  }

  void _removeDigit() {
    if (pin.isNotEmpty) {
      setState(() {
        pin = pin.substring(0, pin.length - 1);
      });
    }
  }

  Future<void> _validatePin() async {
    final isValid = await _securityService.verifyPin(pin);

    if (!mounted) return;

    if (isValid) {
      _safeGo(widget.redirectTo);
    } else {
      setState(() {
        pin = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN incorrecto'),
        ),
      );
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
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.lock_rounded,
                size: 54,
                color: Color(0xFF0F62FE),
              ),
              const SizedBox(height: 20),
              const Text(
                'Wallet bloqueado',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Usa biometría o PIN para acceder a tus credenciales.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _authenticateWithBiometrics,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Usar biometría'),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => _buildDot(index < pin.length),
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  children: [
                    ...List.generate(9, (index) {
                      final number = (index + 1).toString();
                      return _buildKey(number);
                    }),
                    const SizedBox(),
                    _buildKey('0'),
                    GestureDetector(
                      onTap: _removeDigit,
                      child: const Icon(Icons.backspace_outlined),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
