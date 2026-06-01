import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  Future<bool> _processQr(String value) async {
    try {
      final data = jsonDecode(value);

      if (data is! Map<String, dynamic>) {
        return false;
      }

      // QR KEY

      if (data['type'] == 'wallet_key_file') {
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

      // QR CER

      if (data['type'] == 'wallet_cer_file') {
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

  Future<void> _handleQrValue(String value) async {
    final normalizedValue = value.trim();

    if (_handledScan || normalizedValue.isEmpty || !mounted) {
      return;
    }

    _handledScan = true;

    try {
      await _controller.stop();
    } catch (_) {}

    final handled = await _processQr(normalizedValue);

    if (!handled && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QR no válido.')));

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
            20,
            20,
            20,
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

            onDetect: (barcodeCapture) {
              if (_handledScan) return;

              for (final barcode in barcodeCapture.barcodes) {
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
                      'Escanea el QR KEY o CER generado por el portal.',

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
