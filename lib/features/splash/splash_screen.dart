import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/session_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SessionService _sessionService = SessionService();
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _redirectTimer = Timer(const Duration(seconds: 2), _checkAndRoute);
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAndRoute() async {
    final isCompromised = await _isDeviceCompromised();
    if (!mounted) return;

    if (isCompromised) {
      _showSecurityBlocker();
      return;
    }

    final hasSession = await _sessionService.hasSession();
    if (!mounted) return;

    context.go(hasSession ? '/pin' : '/login');
  }

  /// Detección de root/jailbreak sin dependencias externas.
  /// Solo activa en release — los builds de debug dan falsos positivos.
  Future<bool> _isDeviceCompromised() async {
    if (kDebugMode) return false;

    try {
      if (Platform.isAndroid) {
        return await _isRootedAndroid();
      }
      if (Platform.isIOS) {
        return await _isJailbrokenIos();
      }
      return false;
    } catch (_) {
      // Si la detección lanza, asumimos seguro para evitar falsos positivos.
      return false;
    }
  }

  Future<bool> _isRootedAndroid() async {
    // Rutas conocidas de binarios su en dispositivos rooteados
    const suPaths = [
      '/system/app/Superuser.apk',
      '/system/xbin/su',
      '/system/bin/su',
      '/sbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/data/local/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/tmp/su',
    ];

    for (final path in suPaths) {
      try {
        if (await File(path).exists()) return true;
      } catch (_) {}
    }

    // Verificar build tags del sistema (test-keys indica ROM no oficial)
    try {
      const channel = MethodChannel('identity_wallet/security');
      final buildTags =
          await channel.invokeMethod<String>('getBuildTags') ?? '';
      if (buildTags.contains('test-keys')) return true;
    } catch (_) {
      // Si el canal no está implementado, continuamos
    }

    return false;
  }

  Future<bool> _isJailbrokenIos() async {
    // Apps y rutas características de dispositivos con jailbreak
    const jailbreakPaths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt',
      '/usr/bin/ssh',
    ];

    for (final path in jailbreakPaths) {
      try {
        if (await File(path).exists()) return true;
      } catch (_) {}
    }

    return false;
  }

  void _showSecurityBlocker() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Dispositivo no seguro'),
        content: const Text(
          'Este dispositivo tiene acceso root o jailbreak activo. '
          'Por seguridad, el wallet no puede ejecutarse en dispositivos comprometidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Identity Wallet',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
