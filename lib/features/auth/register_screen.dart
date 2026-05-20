import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Alta con QR'),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF0F62FE),
                  size: 34,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Darte de alta con QR',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Genera el QR en el portal, escanealo aqui y confirma el alta para recibir tu credencial firmada en el wallet.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/scan'),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Escanear QR del portal'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Volver al acceso'),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
