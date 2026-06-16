// Pantalla principal del wallet — muestra identidad, credenciales y actividad.
// Usa Riverpod para el estado de credenciales y carga datos del usuario
// desde SessionService y CryptoIdentityService al inicializar.
// Soporta pull-to-refresh para actualizar credenciales y actividad.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/crypto_identity_service.dart';
import '../../core/services/session_service.dart';
import '../../core/services/wallet_activity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/credential.dart';
import 'providers/credential_provider.dart';

class WalletHomeScreen extends ConsumerStatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  ConsumerState<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends ConsumerState<WalletHomeScreen> {
  final _sessionService  = SessionService();
  final _activityService = WalletActivityService();

  bool   _loading        = true;
  String _userName       = 'Usuario';
  String _userInitials   = 'US';
  String _email          = '';
  String _walletAlias    = '';
  String _didLabel       = '';
  bool   _identityVerified = false;
  List<WalletEvent> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  /// Carga en paralelo datos del usuario, identidad DID y actividad reciente.
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadUserData(), _loadActivity()]);
    if (mounted) setState(() => _loading = false);
  }

  /// Lee los datos de sesión y recupera/genera la identidad Ed25519 del holder.
  Future<void> _loadUserData() async {
    final name     = await _sessionService.getUserName();
    final email    = await _sessionService.getUserEmail();
    final alias    = await _sessionService.getWalletAlias();
    final verified = await _sessionService.isIdentityVerified();
    final identity = await CryptoIdentityService().getOrCreateIdentity();
    if (!mounted) return;
    setState(() {
      _userName         = name.isNotEmpty ? name : 'Usuario';
      _email            = email;
      _walletAlias      = alias;
      _identityVerified = verified;
      _userInitials     = _initials(name);
      _didLabel         = _shortDid(identity.did);
    });
  }

  /// Carga los últimos 5 eventos del historial local del wallet.
  Future<void> _loadActivity() async {
    final events = await _activityService.getRecentEvents(limit: 5);
    if (!mounted) return;
    setState(() => _recentActivity = events);
  }

  /// Extrae las primeras 2 iniciales del nombre completo.
  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'US';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Acorta un DID largo para que sea legible en una sola línea.
  String _shortDid(String did) {
    if (did.length <= 24) return did;
    return '${did.substring(0, 12)}…${did.substring(did.length - 8)}';
  }

  /// Cierra la sesión local y navega al login.
  Future<void> _logout() async {
    await _activityService.addEvent(
      type: WalletEventType.logout,
      description: 'Sesión cerrada',
    );
    await _sessionService.clearSession();
    if (!mounted) return;
    context.go('/login');
  }

  /// Refresca datos al hacer pull-to-refresh.
  Future<void> _onRefresh() => _loadAll();

  @override
  Widget build(BuildContext context) {
    final credentials = ref.watch(credentialsProvider);
    final firstName   = _userName.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi Wallet'),
        actions: [
          IconButton(
            tooltip: 'Actividad',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => _showActivity(context),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/issue-credential'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  // ── Saludo personalizado ──────────────────────────────
                  _GreetingHeader(firstName: firstName),
                  const SizedBox(height: 20),

                  // ── Tarjeta hero de identidad ─────────────────────────
                  _IdentityCard(
                    name: _userName,
                    email: _email,
                    alias: _walletAlias,
                    initials: _userInitials,
                    didLabel: _didLabel,
                    verified: _identityVerified,
                  ),
                  const SizedBox(height: 20),

                  // ── Acciones rápidas ──────────────────────────────────
                  _QuickActions(
                    onShare: () => context.push('/qr'),
                    onScan:  () => context.push('/scan'),
                    onAdd:   () => context.push('/issue-credential'),
                  ),
                  const SizedBox(height: 28),

                  // ── Credenciales ──────────────────────────────────────
                  _SectionHeader(
                    title: 'Mis credenciales',
                    actionLabel: credentials.isNotEmpty ? 'Agregar' : null,
                    onAction: credentials.isNotEmpty
                        ? () => context.push('/issue-credential')
                        : null,
                  ),
                  const SizedBox(height: 12),

                  if (credentials.isEmpty)
                    _EmptyCredentials(onScan: () => context.push('/scan'))
                  else
                    ...credentials.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CredentialCard(
                          credential: c,
                          onTap: () => context.push('/credential', extra: c),
                        ),
                      ),
                    ),

                  const SizedBox(height: 28),

                  // ── Actividad reciente ────────────────────────────────
                  const _SectionHeader(title: 'Actividad reciente'),
                  const SizedBox(height: 12),

                  if (_recentActivity.isEmpty)
                    const _EmptyActivity()
                  else
                    ..._recentActivity.map((e) => _ActivityRow(event: e)),
                ],
              ),
            ),
    );
  }

  /// Muestra el historial de actividad en un bottom sheet.
  void _showActivity(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, sc) => _ActivitySheet(
          events: _recentActivity,
          scrollController: sc,
        ),
      ),
    );
  }
}

// ─── Widgets de soporte ──────────────────────────────────────────────────────

/// Saludo personalizado con hora del día y nombre.
class _GreetingHeader extends StatelessWidget {
  final String firstName;
  const _GreetingHeader({required this.firstName});

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greeting = h < 12 ? 'Buenos días' : h < 19 ? 'Buenas tardes' : 'Buenas noches';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $firstName 👋',
          style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tu identidad digital está protegida.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Tarjeta hero con gradiente azul y datos de la identidad digital.
class _IdentityCard extends StatelessWidget {
  final String name, email, alias, initials, didLabel;
  final bool verified;
  const _IdentityCard({
    required this.name, required this.email, required this.alias,
    required this.initials, required this.didLabel, required this.verified,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: AppRadius.heroCard,
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: AppShadow.identity,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26, backgroundColor: Colors.white,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16,
                    ),
                  ),
                ),
                const Spacer(),
                _VerifiedBadge(verified: verified),
              ],
            ),
            const SizedBox(height: 18),
            const Text('IDENTIDAD DIGITAL',
                style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(name,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.all(Radius.circular(14)),
              ),
              child: Column(
                children: [
                  _CardRow(label: 'Correo', value: email.isNotEmpty ? email : 'No configurado'),
                  const SizedBox(height: 6),
                  _CardRow(label: 'Alias',  value: alias.isNotEmpty ? alias : 'No configurado'),
                  const SizedBox(height: 6),
                  _CardRow(label: 'DID',    value: didLabel.isNotEmpty ? didLabel : 'Generando…'),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CardRow extends StatelessWidget {
  final String label, value;
  const _CardRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          Expanded(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      );
}

class _VerifiedBadge extends StatelessWidget {
  final bool verified;
  const _VerifiedBadge({required this.verified});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: AppRadius.badge,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(verified ? Icons.verified_rounded : Icons.schedule_rounded, color: Colors.white, size: 13),
            const SizedBox(width: 5),
            Text(verified ? 'Verificada' : 'Pendiente',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onShare, onScan, onAdd;
  const _QuickActions({required this.onShare, required this.onScan, required this.onAdd});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _ActionBtn(icon: Icons.qr_code_rounded,         label: 'Compartir', onTap: onShare)),
          const SizedBox(width: 10),
          Expanded(child: _ActionBtn(icon: Icons.qr_code_scanner_rounded, label: 'Escanear',  onTap: onScan)),
          const SizedBox(width: 10),
          Expanded(child: _ActionBtn(icon: Icons.add_circle_outline,      label: 'Agregar',   onTap: onAdd)),
        ],
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.primary, size: 24),
                const SizedBox(height: 6),
                Text(label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      );
}

class _EmptyCredentials extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyCredentials({required this.onScan});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 12),
            const Text('Sin credenciales',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text(
              'Escanea el QR del portal para recibir tu primera credencial firmada.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Escanear QR del portal'),
              ),
            ),
          ],
        ),
      );
}

class _CredentialCard extends StatelessWidget {
  final Credential credential;
  final VoidCallback onTap;
  const _CredentialCard({required this.credential, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final expired = credential.expiresAt != null && credential.expiresAt!.isBefore(DateTime.now());
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: expired ? AppColors.error.withValues(alpha: 0.3) : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: expired ? AppColors.errorLight : AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(credential.icon, color: expired ? AppColors.error : AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(credential.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(credential.subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (credential.expiresAt != null)
                    Text(
                      expired ? 'Expirada' : 'Vence ${_fmt(credential.expiresAt!)}',
                      style: TextStyle(fontSize: 11, color: expired ? AppColors.error : AppColors.textTertiary),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: expired ? AppColors.errorLight : AppColors.successLight,
                borderRadius: AppRadius.badge,
              ),
              child: Text(
                expired ? 'Expirada' : credential.status,
                style: TextStyle(
                  color: expired ? AppColors.error : AppColors.success,
                  fontSize: 11, fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2,'0')}/${l.month.toString().padLeft(2,'0')}/${l.year}';
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Sin actividad registrada aún.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
      );
}

class _ActivityRow extends StatelessWidget {
  final WalletEvent event;
  const _ActivityRow({required this.event});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: const BoxDecoration(color: AppColors.surfaceVariant, shape: BoxShape.circle),
              child: Icon(event.icon, color: event.iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.description,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(event.timeAgo,
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActivitySheet extends StatelessWidget {
  final List<WalletEvent> events;
  final ScrollController scrollController;
  const _ActivitySheet({required this.events, required this.scrollController});
  @override
  Widget build(BuildContext context) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          const Text('Historial de actividad',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          if (events.isEmpty)
            const Text('Sin actividad.', style: TextStyle(color: AppColors.textSecondary))
          else
            ...events.map((e) => _ActivityRow(event: e)),
        ],
      );
}
