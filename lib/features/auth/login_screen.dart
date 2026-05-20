import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/session_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final SessionService _sessionService = SessionService();

  Future<void> _openExistingWallet() async {
    final hasSession = await _sessionService.hasSession();

    if (!mounted) return;

    if (hasSession) {
      context.go('/pin');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Primero escanea un QR del portal para dar de alta este wallet.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const CircleAvatar(
                radius: 36,
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF0F62FE),
                  size: 38,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Alta por QR del portal',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Escanea la invitacion generada en el portal para crear tu DID, completar el alta y guardar tu credencial firmada.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/scan'),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Escanear QR para darme de alta'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _openExistingWallet,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Ya tengo wallet en este dispositivo'),
                ),
              ),
              const Spacer(),
              const Text(
                'Este wallet no usa registro manual. El acceso se habilita cuando el portal emite la credencial.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
