import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/wallet_security_service.dart';

class SetPinScreen extends StatefulWidget {
  final String redirectTo;

  const SetPinScreen({super.key, this.redirectTo = '/wallet'});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final WalletSecurityService _securityService = WalletSecurityService();

  String _pin = '';
  String _confirmPin = '';
  bool _confirming = false;
  bool _navigating = false;

  void _safeGo(String location) {
    if (_navigating || !mounted) return;
    _navigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(location);
    });
  }

  void _addDigit(String digit) {
    if (_confirming) {
      if (_confirmPin.length >= 4) return;
      setState(() => _confirmPin += digit);
      if (_confirmPin.length == 4) _validateAndSave();
    } else {
      if (_pin.length >= 4) return;
      setState(() => _pin += digit);
      if (_pin.length == 4) setState(() => _confirming = true);
    }
  }

  void _removeDigit() {
    setState(() {
      if (_confirming) {
        if (_confirmPin.isEmpty) {
          _confirming = false;
        } else {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _validateAndSave() async {
    if (_pin != _confirmPin) {
      setState(() {
        _pin = '';
        _confirmPin = '';
        _confirming = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los PINs no coinciden. Inténtalo de nuevo.'),
        ),
      );
      return;
    }

    await _securityService.setPin(_pin);
    _safeGo(widget.redirectTo);
  }

  Widget _buildDots(String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        4,
        (i) => Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < value.length ? Colors.black : Colors.grey.shade300,
          ),
        ),
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
    final current = _confirming ? _confirmPin : _pin;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.lock_outline_rounded,
                size: 54,
                color: Color(0xFF0F62FE),
              ),
              const SizedBox(height: 20),
              Text(
                _confirming ? 'Confirma tu PIN' : 'Crea tu PIN',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _confirming
                    ? 'Ingresa de nuevo tu PIN de 4 dígitos para confirmar.'
                    : 'Elige un PIN de 4 dígitos para proteger tu wallet.',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildDots(current),
              if (_confirming) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _confirming = false;
                    _confirmPin = '';
                  }),
                  child: const Text('Cambiar PIN'),
                ),
              ],
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  children: [
                    ...List.generate(9, (i) => _buildKey((i + 1).toString())),
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
