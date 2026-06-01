import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/services/session_service.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _manualQrController = TextEditingController();
  final SessionService _sessionService = SessionService();

  bool _handledScan = false;

  @override
  void dispose() {
    _manualQrController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ─── Procesador central de QR ────────────────────────────────────────────

  Future<bool> _processQr(String value) async {
    try {
      final data = jsonDecode(value);
      if (data is! Map<String, dynamic>) return false;

      final type = data['type']?.toString() ?? '';

      // ── Nuevo: sesión de archivos del portal (QR pequeño) ──────────────
      if (type == 'wallet_file_session') {
        await _handleFileSession(data);
        return true;
      }

      // ── Legacy: QR KEY con contenido completo en base64 ─────────────────
      if (type == 'wallet_key_file') {
        await _sessionService.saveKeyDocumentFromQr(
          keyFileName: data['key_file_name'] ?? '',
          keyContentBase64: data['key_content_base64'] ?? '',
        );
        if (!mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo KEY cargado correctamente')),
        );
        context.go('/login?create=true&step=2');
        return true;
      }

      // ── Legacy: QR CER con contenido completo en base64 ─────────────────
      if (type == 'wallet_cer_file') {
        await _sessionService.saveCerDocumentFromQr(
          cerFileName: data['cer_file_name'] ?? '',
          cerContentBase64: data['cer_content_base64'] ?? '',
        );
        if (!mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo CER cargado correctamente')),
        );
        context.go('/login?create=true&step=2');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error procesando QR: $e');
      return false;
    }
  }

  // ─── Flujo wallet_file_session ────────────────────────────────────────────

  Future<void> _handleFileSession(Map<String, dynamic> data) async {
    final sessionId  = data['session_id']?.toString() ?? '';
    final claimToken = data['claim_token']?.toString() ?? '';
    final issuerUrl  = data['issuer_url']?.toString() ?? '';

    if (sessionId.isEmpty || claimToken.isEmpty || issuerUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR de sesión incompleto.')),
        );
      }
      return;
    }

    // Mostrar diálogo de progreso
    if (!mounted) return;
    _showLoadingDialog('Reclamando archivos del portal…');

    try {
      final result = await _claimFiles(
        issuerUrl: issuerUrl,
        sessionId: sessionId,
        claimToken: claimToken,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // cerrar diálogo

      await _sessionService.saveDocumentsFromQr(
        cerFileName: result['cer_filename'] as String? ?? 'identity.cer',
        keyFileName: result['key_filename'] as String? ?? 'identity.key',
        cerContentBase64: result['cer_base64'] as String? ?? '',
        keyContentBase64: result['key_base64'] as String? ?? '',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Archivos .cer y .key recibidos correctamente.'),
        ),
      );
      context.go('/login?create=true&step=2');
    } on _FilesNotReadyException {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showFilesNotReadyDialog();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo reclamar los archivos: $e')),
        );
        // Reanudar escáner para reintentar
        _handledScan = false;
        await _controller.start();
      }
    }
  }

  Future<Map<String, dynamic>> _claimFiles({
    required String issuerUrl,
    required String sessionId,
    required String claimToken,
  }) async {
    final uri = _resolveUri('$issuerUrl/sessions/$sessionId/claim');

    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'claim_token': claimToken, 'holder_did': ''}),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 425) {
      throw _FilesNotReadyException();
    }
    if (response.statusCode != 200 || body['ok'] != true) {
      throw Exception(body['detail']?.toString() ?? 'HTTP ${response.statusCode}');
    }
    return body;
  }

  /// Ajusta localhost/127.0.0.1 a 10.0.2.2 en emulador Android.
  Uri _resolveUri(String url) {
    final uri = Uri.parse(url);
    if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      return uri.replace(host: '10.0.2.2');
    }
    return uri;
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(width: 20),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilesNotReadyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivos pendientes'),
        content: const Text(
          'Los archivos aún no han sido subidos.\n\n'
          'El usuario debe abrir el enlace del correo en su computadora '
          'y subir los archivos .cer y .key antes de escanear este QR.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handledScan = false;
              _controller.start();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // ─── Manejo del escaneo ───────────────────────────────────────────────────

  Future<void> _handleQrValue(String value) async {
    final normalized = value.trim();
    if (_handledScan || normalized.isEmpty || !mounted) return;

    _handledScan = true;
    try {
      await _controller.stop();
    } catch (_) {}

    final handled = await _processQr(normalized);

    if (!handled && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('QR no válido.')));
      _handledScan = false;
      await _controller.start();
    }
  }

  void _openManualQrInput() {
    _manualQrController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pegar contenido QR',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _manualQrController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Contenido QR',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final value = _manualQrController.text;
                    Navigator.of(context).pop();
                    _handleQrValue(value);
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Procesar QR'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear QR'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            onPressed: _controller.toggleTorch,
            icon: const Icon(Icons.flash_on_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: (capture) {
              if (_handledScan) return;
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue;
                if (value != null && value.trim().isNotEmpty) {
                  _handleQrValue(value);
                  break;
                }
              }
            },
          ),
          const _ScannerFrame(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Escanea el QR generado por el portal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        onPressed: _openManualQrInput,
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Pegar contenido QR'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Excepción interna ────────────────────────────────────────────────────────

class _FilesNotReadyException implements Exception {
  const _FilesNotReadyException();
}

// ─── Frame visual del escáner ─────────────────────────────────────────────────

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 264,
          height: 264,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
