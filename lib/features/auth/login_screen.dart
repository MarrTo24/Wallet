import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/services/portal_file_service.dart';
import '../../core/services/session_service.dart';
import '../../core/services/wallet_activity_service.dart';
import '../../core/services/wallet_security_service.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final SessionService _sessionService      = SessionService();
  final WalletSecurityService _securityService = WalletSecurityService();
  final PortalFileService _portalService    = PortalFileService();
  final ApiService _apiService              = ApiService();
  final WalletActivityService _activity     = WalletActivityService();

  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _aliasController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _portalUrlController = TextEditingController(
    text: 'http://192.168.100.115:8010',
  );

  bool _isCreatingAccount = false;
  int  _createStep = 1;
  bool _generatedFiles = false;

  // Archivos locales (subida manual)
  String _cerFileName = '';
  String _keyFileName = '';
  String _cerBase64   = '';
  String _keyBase64   = '';

  // Estado del flujo "recibir por correo"
  PortalSession? _portalSession;
  PortalSessionStatus _portalStatus = PortalSessionStatus.unknown;
  Timer? _pollTimer;
  bool _claimingFiles = false;

  bool get _hasDocuments =>
      (_cerBase64.isNotEmpty && _keyBase64.isNotEmpty) || _generatedFiles;

  bool get _hasPortalSession => _portalSession != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri  = GoRouterState.of(context).uri;
      final create = uri.queryParameters['create'];
      final step   = uri.queryParameters['step'];
      if (create == 'true') {
        setState(() {
          _isCreatingAccount = true;
          _createStep = step == '2' ? 2 : 1;
        });
      }
      _loadStoredDocuments();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _aliasController.dispose();
    _passwordController.dispose();
    _portalUrlController.dispose();
    super.dispose();
  }

  // ─── Carga documentos guardados ─────────────────────────────────────────

  Future<void> _loadStoredDocuments() async {
    final cerName   = await _sessionService.getCerFileName();
    final keyName   = await _sessionService.getKeyFileName();
    final cerBase64 = await _sessionService.getCerContentBase64();
    final keyBase64 = await _sessionService.getKeyContentBase64();
    if (!mounted) return;
    setState(() {
      _cerFileName = cerName;
      _keyFileName = keyName;
      _cerBase64   = cerBase64;
      _keyBase64   = keyBase64;
      if (_isCreatingAccount) _createStep = 2;
    });
  }

  // ─── Login ───────────────────────────────────────────────────────────────

  /// Inicia sesión: verifica credenciales locales y opcionalmente con el backend.
  Future<void> _login() async {
    final email    = _emailController.text.trim();
    final alias    = _aliasController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || alias.isEmpty || password.isEmpty) {
      _showSnack('Ingresa correo, alias wallet y password.');
      return;
    }

    // Intentar autenticar con el backend si está configurado
    final portalUrl = _portalUrlController.text.trim();
    if (portalUrl.isNotEmpty) {
      try {
        await _apiService.setBaseUrl(portalUrl);
        final res = await _apiService.post('/api/auth/login', body: {
          'email': email,
          'password': password,
        });
        // Guardar JWT del backend
        await _apiService.saveSession(
          token: res['access_token'] as String? ?? '',
          name:  res['name']  as String? ?? alias,
          email: res['email'] as String? ?? email,
        );
      } on ApiException catch (e) {
        // Si el error es 401 (credenciales incorrectas), bloquear
        if (e.statusCode == 401) {
          _showSnack('Correo o contraseña incorrectos.');
          return;
        }
        // Otros errores (conexión, servidor caído) — continuar en modo offline
        debugPrint('Backend no disponible, modo offline: $e');
      } catch (e) {
        debugPrint('Backend no disponible, modo offline: $e');
      }
    }

    await _sessionService.saveSession(
      name: alias, email: email, alias: alias, password: password,
    );
    await _activity.addEvent(
      type: WalletEventType.login,
      description: 'Sesión iniciada',
    );
    if (!mounted) return;
    final hasPin = await _securityService.hasPin();
    if (!mounted) return;
    context.go(hasPin ? '/wallet' : '/set-pin', extra: '/wallet');
  }

  // ─── Crear cuenta ────────────────────────────────────────────────────────

  /// Crea una cuenta nueva: registra en backend si está disponible y guarda localmente.
  Future<void> _createAccount() async {
    final name     = _nameController.text.trim();
    final email    = _emailController.text.trim();
    final alias    = _aliasController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || alias.isEmpty || password.isEmpty) {
      _showSnack('Completa todos los campos para crear tu cuenta.');
      return;
    }
    if (!_hasDocuments) {
      _showSnack('Primero vincula tus archivos .cer y .key.');
      return;
    }

    // Registrar en el backend si hay URL configurada
    final portalUrl = _portalUrlController.text.trim();
    if (portalUrl.isNotEmpty) {
      try {
        await _apiService.setBaseUrl(portalUrl);
        final res = await _apiService.post('/api/auth/register', body: {
          'name':     name,
          'email':    email,
          'alias':    alias,
          'password': password,
        });
        await _apiService.saveSession(
          token: res['access_token'] as String? ?? '',
          name:  res['name']  as String? ?? name,
          email: res['email'] as String? ?? email,
        );
      } on ApiException catch (e) {
        if (e.statusCode == 409) {
          _showSnack('Ya existe una cuenta con ese correo en el portal.');
          return;
        }
        debugPrint('Backend no disponible, modo offline: $e');
      } catch (e) {
        debugPrint('Backend no disponible, modo offline: $e');
      }
    }

    await _sessionService.saveSession(
      name: name, email: email, alias: alias, password: password,
    );
    if (_cerBase64.isNotEmpty && _keyBase64.isNotEmpty) {
      await _sessionService.saveDocumentsFromQr(
        cerFileName: _cerFileName,
        keyFileName: _keyFileName,
        cerContentBase64: _cerBase64,
        keyContentBase64: _keyBase64,
      );
    }
    await _activity.addEvent(
      type: WalletEventType.login,
      description: 'Cuenta creada — primer ingreso',
    );
    if (!mounted) return;
    final hasPin = await _securityService.hasPin();
    if (!mounted) return;
    context.go(hasPin ? '/wallet' : '/set-pin', extra: '/wallet');
  }

  // ─── Subida manual de archivos ───────────────────────────────────────────

  Future<void> _pickDocumentFiles() async {
    final cerResult = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['cer'], withData: true,
    );
    if (cerResult == null || cerResult.files.single.bytes == null) return;

    final keyResult = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['key'], withData: true,
    );
    if (keyResult == null || keyResult.files.single.bytes == null) return;

    final cerFile = cerResult.files.single;
    final keyFile = keyResult.files.single;
    setState(() {
      _cerFileName = cerFile.name;
      _keyFileName = keyFile.name;
      _cerBase64   = base64Encode(cerFile.bytes!);
      _keyBase64   = base64Encode(keyFile.bytes!);
      _generatedFiles = false;
    });
    if (!mounted) return;
    _showSnack('Archivos .cer y .key seleccionados correctamente.');
  }

  // ─── Flujo "Recibir por correo" ──────────────────────────────────────────

  Future<void> _requestFilesViaEmail() async {
    // Usa la URL guardada en ApiService; si no hay, usa el default del controlador
    final storedUrl = await _apiService.getBaseUrl();
    final portalUrl = (storedUrl != null && storedUrl.isNotEmpty)
        ? storedUrl
        : _portalUrlController.text.trim();

    final email      = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : _nameController.text.trim();
    final holderName = _nameController.text.trim();
    final alias      = _aliasController.text.trim();

    if (portalUrl.isEmpty) {
      _showSnack('Configura la URL del portal en ajustes.');
      return;
    }
    if (email.isEmpty) {
      _showSnack('Ingresa tu correo electrónico primero.');
      return;
    }

    setState(() => _claimingFiles = true);

    try {
      final session = await _portalService.createSession(
        portalUrl: portalUrl,
        email: email,
        holderName: holderName.isNotEmpty ? holderName : email,
        alias: alias.isNotEmpty ? alias : email,
      );

      setState(() {
        _portalSession  = session;
        _portalStatus   = PortalSessionStatus.waiting;
        _claimingFiles  = false;
      });

      if (session.emailSent) {
        _showSnack('📧 Correo enviado a $email.');
      } else {
        _showSnack(
          'No se pudo enviar el correo. Usa el enlace que aparece en pantalla.',
          durationSec: 6,
        );
      }

      _startPolling();
    } catch (e) {
      setState(() => _claimingFiles = false);
      _showSnack('Error: $e');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_portalSession == null) return;
      final status = await _portalService.getStatus(_portalSession!);
      if (!mounted) return;
      setState(() => _portalStatus = status);
      if (status == PortalSessionStatus.filesReady ||
          status == PortalSessionStatus.consumed ||
          status == PortalSessionStatus.expired) {
        _pollTimer?.cancel();
      }
    });
  }

  Future<void> _claimFiles() async {
    if (_portalSession == null) return;
    setState(() => _claimingFiles = true);

    try {
      final result = await _portalService.claimFiles(_portalSession!);
      await _sessionService.saveDocumentsFromQr(
        cerFileName: result.cerFilename,
        keyFileName: result.keyFilename,
        cerContentBase64: result.cerBase64,
        keyContentBase64: result.keyBase64,
      );
      setState(() {
        _cerFileName    = result.cerFilename;
        _keyFileName    = result.keyFilename;
        _cerBase64      = result.cerBase64;
        _keyBase64      = result.keyBase64;
        _claimingFiles  = false;
        _portalSession  = null;
        _portalStatus   = PortalSessionStatus.unknown;
        _pollTimer?.cancel();
      });
      _showSnack('✅ Archivos .cer y .key recibidos correctamente.');
    } on PortalFilesNotReadyException {
      setState(() => _claimingFiles = false);
      _showSnack(
        'Los archivos aún no están listos. Súbelos desde el correo y vuelve a intentar.',
        durationSec: 5,
      );
    } catch (e) {
      setState(() => _claimingFiles = false);
      _showSnack('Error al obtener archivos: $e');
    }
  }

  void _cancelPortalSession() {
    _pollTimer?.cancel();
    setState(() {
      _portalSession = null;
      _portalStatus  = PortalSessionStatus.unknown;
    });
  }

  // ─── Navegación entre pasos ──────────────────────────────────────────────

  void _goToDocumentStep() {
    final name     = _nameController.text.trim();
    final email    = _emailController.text.trim();
    final alias    = _aliasController.text.trim();
    final password = _passwordController.text.trim();
    if (name.isEmpty || email.isEmpty || alias.isEmpty || password.isEmpty) {
      _showSnack('Completa todos los campos antes de continuar.');
      return;
    }
    setState(() => _createStep = 2);
  }

  void _switchToCreateAccount() =>
      setState(() { _isCreatingAccount = true; _createStep = 1; });

  void _switchToLogin() => setState(() {
    _isCreatingAccount = false;
    _createStep = 1;
    _generatedFiles = false;
    _cerFileName = _keyFileName = _cerBase64 = _keyBase64 = '';
    _cancelPortalSession();
  });

  void _backToFormStep() => setState(() => _createStep = 1);

  void _showSnack(String msg, {int durationSec = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: Duration(seconds: durationSec),
    ));
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = _isCreatingAccount
        ? (_createStep == 1 ? 'Crear cuenta' : 'Vincular documentos')
        : 'Iniciar sesión';

    final subtitle = _isCreatingAccount
        ? (_createStep == 1
              ? 'Registra tus datos para inicializar tu identidad autosoberana.'
              : 'Vincula tus archivos de identidad para completar el registro.')
        : 'Ingresa con tu correo, alias wallet y password.';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 36),
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.primaryLight,
                child: Icon(
                  _isCreatingAccount && _createStep == 2
                      ? Icons.folder_shared_rounded
                      : Icons.account_balance_wallet_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // ── MODO LOGIN ──────────────────────────────────────────────
              if (!_isCreatingAccount) ...[
                _InputField(controller: _emailController,
                    label: 'Correo', icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _InputField(controller: _aliasController,
                    label: 'Alias wallet', icon: Icons.badge_outlined),
                const SizedBox(height: 14),
                _InputField(controller: _passwordController,
                    label: 'Password', icon: Icons.lock_outline_rounded,
                    obscureText: true),
                const SizedBox(height: 14),
                _InputField(controller: _portalUrlController,
                    label: 'URL del portal', icon: Icons.dns_rounded,
                    keyboardType: TextInputType.url),
                const SizedBox(height: 22),
                _PrimaryButton(
                  icon: Icons.login_rounded, label: 'Iniciar sesión',
                  onPressed: _login,
                ),
                const SizedBox(height: 12),
                _OutlineButton(
                  icon: Icons.person_add_alt_1_rounded, label: 'Crear cuenta',
                  onPressed: _switchToCreateAccount,
                ),
              ],

              // ── CREAR CUENTA — PASO 1 ────────────────────────────────────
              if (_isCreatingAccount && _createStep == 1) ...[
                _InputField(controller: _nameController,
                    label: 'Nombre completo',
                    icon: Icons.person_outline_rounded),
                const SizedBox(height: 14),
                _InputField(controller: _emailController,
                    label: 'Correo', icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _InputField(controller: _aliasController,
                    label: 'Alias wallet', icon: Icons.badge_outlined),
                const SizedBox(height: 14),
                _InputField(controller: _passwordController,
                    label: 'Password', icon: Icons.lock_outline_rounded,
                    obscureText: true),
                const SizedBox(height: 24),
                _PrimaryButton(
                  icon: Icons.arrow_forward_rounded, label: 'Siguiente',
                  onPressed: _goToDocumentStep,
                ),
                const SizedBox(height: 12),
                _TextBtn(
                  icon: Icons.arrow_back_rounded,
                  label: 'Volver a iniciar sesión',
                  onPressed: _switchToLogin,
                ),
              ],

              // ── CREAR CUENTA — PASO 2: DOCUMENTOS ───────────────────────
              if (_isCreatingAccount && _createStep == 2) ...[

                // Estado de documentos actuales
                _DocumentStatusCard(
                  cerFileName: _cerFileName,
                  keyFileName: _keyFileName,
                  generatedFiles: _generatedFiles,
                ),
                const SizedBox(height: 20),

                // ── OPCIÓN 1: Recibir por correo desde PC ────────────────
                if (!_hasPortalSession) ...[
                  _SectionLabel(label: 'Opción 1 — Portal'),
                  _InputField(
                    controller: _portalUrlController,
                    label: 'URL del portal',
                    icon: Icons.dns_rounded,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  _PortalEmailCard(
                    loading: _claimingFiles,
                    onSend: _requestFilesViaEmail,
                  ),
                  const SizedBox(height: 16),
                  const _Divider(label: 'otras opciones'),
                  const SizedBox(height: 16),
                ],

                // ── SESIÓN EN CURSO: esperando archivos ──────────────────
                if (_hasPortalSession) ...[
                  _PortalWaitingCard(
                    session: _portalSession!,
                    status: _portalStatus,
                    loading: _claimingFiles,
                    onClaim: _claimFiles,
                    onCancel: _cancelPortalSession,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── OPCIONES 2-4 ──────────────────────────────────────────
                if (!_hasPortalSession) ...[
                  // Opción 2: cargar archivos desde este dispositivo
                  _SectionLabel(label: 'Opción 2 — Desde este dispositivo'),
                  _OutlineButton(
                    icon: Icons.phone_android_rounded,
                    label: 'Cargar archivos desde este dispositivo',
                    onPressed: _pickDocumentFiles,
                  ),
                  const SizedBox(height: 12),
                  // Opción 3: escanear QR del portal
                  _OutlineButton(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Escanear QR del portal',
                    onPressed: () => context.go('/scan'),
                  ),
                  const SizedBox(height: 12),
                  // Opción 4: crear archivos (próximamente — pendiente código SeguriData)
                  _DisabledButton(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Crear archivos .cer y .key',
                    tooltip: 'Próximamente — funcionalidad en desarrollo',
                  ),
                ],

                const SizedBox(height: 20),

                // ── BOTÓN CREAR CUENTA ───────────────────────────────────
                _PrimaryButton(
                  icon: Icons.verified_user_rounded,
                  label: 'Crear cuenta',
                  onPressed: _hasDocuments ? _createAccount : null,
                ),
                const SizedBox(height: 12),
                _TextBtn(
                  icon: Icons.arrow_back_rounded,
                  label: 'Volver al formulario',
                  onPressed: _backToFormStep,
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tarjeta: Recibir por correo ──────────────────────────────────────────────

class _PortalEmailCard extends StatelessWidget {
  final bool loading;
  final VoidCallback onSend;

  const _PortalEmailCard({
    required this.loading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mark_email_unread_outlined,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Recibir archivos por correo',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Se enviará un enlace seguro a tu correo para subir los archivos '
            '.cer y .key desde tu computadora. Los archivos se entregan directamente '
            'al wallet y no se almacenan en ningún servidor.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: loading ? null : onSend,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                loading ? 'Enviando…' : 'Enviar enlace a mi correo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tarjeta: Esperando archivos ──────────────────────────────────────────────

class _PortalWaitingCard extends StatelessWidget {
  final PortalSession session;
  final PortalSessionStatus status;
  final bool loading;
  final VoidCallback onClaim;
  final VoidCallback onCancel;

  const _PortalWaitingCard({
    required this.session,
    required this.status,
    required this.loading,
    required this.onClaim,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final filesReady = status == PortalSessionStatus.filesReady;
    final expired    = status == PortalSessionStatus.expired;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: filesReady
            ? AppColors.successLight
            : expired
                ? AppColors.warningLight
                : AppColors.surfaceVariant,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: filesReady
              ? AppColors.success.withValues(alpha: 0.4)
              : expired
                  ? AppColors.warning.withValues(alpha: 0.4)
                  : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusDot(filesReady: filesReady, expired: expired),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  filesReady
                      ? 'Archivos listos — puedes obtenerlos'
                      : expired
                          ? 'Sesión expirada'
                          : 'Esperando que subas los archivos…',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: filesReady
                        ? AppColors.success
                        : expired
                            ? AppColors.warning
                            : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (!expired && !filesReady)
            const Text(
              '1. Revisa tu correo\n'
              '2. Abre el enlace en cualquier dispositivo\n'
              '3. Sube tus archivos .cer y .key\n'
              '4. Toca el botón de abajo',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),


          const SizedBox(height: 14),

          if (!expired)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: loading ? null : onClaim,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      filesReady ? AppColors.success : AppColors.primary,
                ),
                icon: loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  loading
                      ? 'Obteniendo archivos…'
                      : filesReady
                          ? 'Obtener archivos ahora'
                          : 'Ya subí los archivos',
                ),
              ),
            ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onCancel,
              child: const Text('Cancelar y volver a opciones'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool filesReady;
  final bool expired;
  const _StatusDot({required this.filesReady, required this.expired});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filesReady
            ? const Color(0xFF22C55E)
            : expired
                ? const Color(0xFFF59E0B)
                : const Color(0xFF3B82F6),
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 0.9,
          ),
        ),
      );
}

class _Divider extends StatelessWidget {
  final String label;
  const _Divider({required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      );
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
    if (!hasCer && !hasKey && !generatedFiles) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.insert_drive_file_outlined,
                color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            const Text('Estado de documentos',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 10),
          _StatusRow(
              label: hasKey ? 'KEY: $keyFileName' : 'KEY pendiente',
              ready: hasKey || generatedFiles),
          const SizedBox(height: 6),
          _StatusRow(
              label: hasCer ? 'CER: $cerFileName' : 'CER pendiente',
              ready: hasCer || generatedFiles),
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
  Widget build(BuildContext context) => Row(
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: ready ? AppColors.success : AppColors.textTertiary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _PrimaryButton(
      {required this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      );
}

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _OutlineButton(
      {required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      );
}

/// Botón deshabilitado con tooltip explicativo — para funciones en desarrollo.
class _DisabledButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  const _DisabledButton(
      {required this.icon, required this.label, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: null, // Deshabilitado — código pendiente
            icon: Icon(icon),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textTertiary,
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      );
}

class _TextBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _TextBtn(
      {required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 46,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      );
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
  Widget build(BuildContext context) => TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
      );
}
