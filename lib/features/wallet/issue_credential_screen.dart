import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class IssueCredentialScreen extends StatelessWidget {
  const IssueCredentialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Agregar credencial'),
        backgroundColor: const Color(0xFFF8FAFC),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/wallet');
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFF0F62FE),
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Credenciales emitidas por el portal',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Para agregar una credencial real, crea una invitacion en el portal web y escanea el QR desde este dispositivo.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flujo recomendado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 14),
                    _StepItem(
                      icon: Icons.web_asset_outlined,
                      title: 'Crear alta en el portal',
                    ),
                    _StepItem(
                      icon: Icons.qr_code_2_rounded,
                      title: 'Escanear la invitacion',
                    ),
                    _StepItem(
                      icon: Icons.key_rounded,
                      title: 'Registrar DID del wallet',
                    ),
                    _StepItem(
                      icon: Icons.badge_outlined,
                      title: 'Guardar credencial firmada',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.go('/scan');
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Escanear QR del portal'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    context.go('/wallet');
                  },
                  child: const Text('Volver al wallet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _StepItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0F62FE)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
