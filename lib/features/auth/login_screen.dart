import 'dart:convert';

import 'package:file_picker/file_picker.dart';
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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isCreatingAccount = false;
  int _createStep = 1;
  bool _generatedFiles = false;

  String _cerFileName = '';
  String _keyFileName = '';
  String _cerBase64 = '';
  String _keyBase64 = '';

  bool get _hasDocuments =>
      (_cerBase64.isNotEmpty &&
          _keyBase64.isNotEmpty &&
          _cerFileName.isNotEmpty &&
          _keyFileName.isNotEmpty) ||
      _generatedFiles;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = GoRouterState.of(context).uri;
      final create = uri.queryParameters['create'];
      final step = uri.queryParameters['step'];

      if (create == 'true') {
        setState(() {
          _isCreatingAccount = true;
          _createStep = step == '2' ? 2 : 1;
        });
      }

      _loadStoredDocuments();
    });
  }

  Future<void> _loadStoredDocuments() async {
    final cerName = await _sessionService.getCerFileName();
    final keyName = await _sessionService.getKeyFileName();
    final cerBase64 = await _sessionService.getCerContentBase64();
    final keyBase64 = await _sessionService.getKeyContentBase64();

    if (!mounted) return;

    setState(() {
      _cerFileName = cerName;
      _keyFileName = keyName;
      _cerBase64 = cerBase64;
      _keyBase64 = keyBase64;

      if (_isCreatingAccount) {
        _createStep = 2;
      }
    });
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final alias = _aliasController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || alias.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa correo, alias wallet y password.'),
        ),
      );
      return;
    }

    await _sessionService.saveSession(
      name: alias,
      email: email,
      alias: alias,
      password: password,
    );

    if (!mounted) return;

    context.go('/wallet');
  }

  Future<void> _createAccount() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final alias = _aliasController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || alias.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos para crear tu cuenta.'),
        ),
      );
      return;
    }

    if (!_hasDocuments) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero sube, escanea o genera tus archivos.'),
        ),
      );
      return;
    }

    await _sessionService.saveSession(
      name: name,
      email: email,
      alias: alias,
      password: password,
    );

    if (_cerBase64.isNotEmpty && _keyBase64.isNotEmpty) {
      await _sessionService.saveDocumentsFromQr(
        cerFileName: _cerFileName,
        keyFileName: _keyFileName,
        cerContentBase64: _cerBase64,
        keyContentBase64: _keyBase64,
      );
    }

    if (!mounted) return;

    context.go('/wallet');
  }

  Future<void> _pickDocumentFiles() async {
    final cerResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cer'],
      withData: true,
    );

    if (cerResult == null || cerResult.files.single.bytes == null) {
      return;
    }

    final keyResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['key'],
      withData: true,
    );

    if (keyResult == null || keyResult.files.single.bytes == null) {
      return;
    }

    final cerFile = cerResult.files.single;
    final keyFile = keyResult.files.single;

    setState(() {
      _cerFileName = cerFile.name;
      _keyFileName = keyFile.name;
      _cerBase64 = base64Encode(cerFile.bytes!);
      _keyBase64 = base64Encode(keyFile.bytes!);
      _generatedFiles = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Archivos .cer y .key seleccionados correctamente.'),
      ),
    );
  }

  void _showGenerateFilesMessage() {
    setState(() {
      _generatedFiles = true;
      _cerFileName = 'archivo_generado.cer';
      _keyFileName = 'archivo_generado.key';
      _cerBase64 = '';
      _keyBase64 = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Opción marcada. Después se conectará con el código interno de generación.',
        ),
      ),
    );
  }

  void _goToDocumentStep() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final alias = _aliasController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || alias.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos antes de continuar.'),
        ),
      );
      return;
    }

    setState(() {
      _createStep = 2;
    });
  }

  void _switchToCreateAccount() {
    setState(() {
      _isCreatingAccount = true;
      _createStep = 1;
    });
  }

  void _switchToLogin() {
    setState(() {
      _isCreatingAccount = false;
      _createStep = 1;
      _generatedFiles = false;
      _cerFileName = '';
      _keyFileName = '';
      _cerBase64 = '';
      _keyBase64 = '';
    });
  }

  void _backToFormStep() {
    setState(() {
      _createStep = 1;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _aliasController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCreatingAccount
        ? (_createStep == 1 ? 'Crear cuenta' : 'Vincular documentos')
        : 'Iniciar sesión';

    final subtitle = _isCreatingAccount
        ? (_createStep == 1
              ? 'Primero registra tus datos para inicializar tu identidad autosoberana.'
              : 'Escanea los QR, sube tus archivos desde el móvil o usa la generación interna.')
        : 'Ingresa con tu correo, alias wallet y password.';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 36),
              CircleAvatar(
                radius: 34,
                backgroundColor: const Color(0xFFEFF6FF),
                child: Icon(
                  _isCreatingAccount && _createStep == 2
                      ? Icons.folder_shared_rounded
                      : Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF0F62FE),
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              if (!_isCreatingAccount) ...[
                _InputField(
                  controller: _emailController,
                  label: 'Correo',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _InputField(
                  controller: _aliasController,
                  label: 'Alias wallet',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 14),
                _InputField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _login,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Iniciar sesión'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _switchToCreateAccount,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Crear cuenta'),
                  ),
                ),
              ],

              if (_isCreatingAccount && _createStep == 1) ...[
                _InputField(
                  controller: _nameController,
                  label: 'Nombre completo',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 14),
                _InputField(
                  controller: _emailController,
                  label: 'Correo',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _InputField(
                  controller: _aliasController,
                  label: 'Alias wallet',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 14),
                _InputField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _goToDocumentStep,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Siguiente'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton.icon(
                    onPressed: _switchToLogin,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Volver a iniciar sesión'),
                  ),
                ),
              ],

              if (_isCreatingAccount && _createStep == 2) ...[
                _DocumentStatusCard(
                  cerFileName: _cerFileName,
                  keyFileName: _keyFileName,
                  generatedFiles: _generatedFiles,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.go('/scan?mode=key');
                    },
                    icon: const Icon(Icons.vpn_key_rounded),
                    label: const Text('Escanear QR archivo KEY'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.go('/scan?mode=cer');
                    },
                    icon: const Icon(Icons.description_rounded),
                    label: const Text('Escanear QR archivo CER'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _pickDocumentFiles,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Subir archivos .cer y .key'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _showGenerateFilesMessage,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Generar archivos .cer y .key'),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _hasDocuments ? _createAccount : null,
                    icon: const Icon(Icons.verified_user_rounded),
                    label: const Text('Crear cuenta'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton.icon(
                    onPressed: _backToFormStep,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Volver al formulario'),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              Center(
                child: Text(
                  _isCreatingAccount
                      ? (_createStep == 1
                            ? 'Después de llenar tus datos podrás vincular tus documentos.'
                            : 'La cuenta solo se puede crear cuando tengas una opción de documentos completa.')
                      : 'También puedes crear una cuenta nueva de identidad autosoberana.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentStatusCard extends StatelessWidget {
  final String cerFileName;
  final String keyFileName;
  final bool generatedFiles;

  const _DocumentStatusCard({
    required this.cerFileName,
    required this.keyFileName,
    required this.generatedFiles,
  });

  @override
  Widget build(BuildContext context) {
    final hasCer = cerFileName.isNotEmpty;
    final hasKey = keyFileName.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado de documentos',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _StatusRow(
            label: hasKey ? 'KEY: $keyFileName' : 'KEY pendiente',
            ready: hasKey || generatedFiles,
          ),
          const SizedBox(height: 8),
          _StatusRow(
            label: hasCer ? 'CER: $cerFileName' : 'CER pendiente',
            ready: hasCer || generatedFiles,
          ),
          if (generatedFiles) ...[
            const SizedBox(height: 10),
            const Text(
              'Archivos marcados como generados. Pendiente conectar lógica interna.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool ready;

  const _StatusRow({required this.label, required this.ready});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ready ? Icons.check_circle_rounded : Icons.schedule_rounded,
          color: ready ? const Color(0xFF16A34A) : const Color(0xFF64748B),
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
