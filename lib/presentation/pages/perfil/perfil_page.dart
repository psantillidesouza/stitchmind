import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../../../core/media/image_pipeline.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/firebase_auth_service.dart';
import '../../providers/platform_providers.dart';
import '../../widgets/gradient_bg.dart';
import '../../widgets/offer_banner.dart';
import '../aulas_salvas/saved_lessons_page.dart';
import 'ajuda_page.dart';
import 'notificacoes_page.dart';

class PerfilPage extends ConsumerWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider) as FirebaseAuthService;
    // Reconstrói quando o nome/foto mudam (updateDisplayName/updatePhotoURL).
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => _buildBody(context, ref, auth),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, FirebaseAuthService auth) {
    final name = (auth.displayName?.trim().isNotEmpty ?? false)
        ? auth.displayName!.trim()
        : context.l10n.tr('perfil_default_name');
    final photo = auth.photoUrl;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _changePhoto(context, ref),
                  child: Stack(
                    children: [
                      Container(
                        width: 104, height: 104,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.coral, AppColors.ochre],
                          ),
                          boxShadow: elevatedShadow(0.16),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.card,
                            shape: BoxShape.circle,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: photo != null
                              ? Image.network(photo, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.person_rounded,
                                          size: 46, color: AppColors.coral)))
                              : const Center(
                                  child: Icon(Icons.person_rounded,
                                      size: 46, color: AppColors.coral)),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.coral,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.card, width: 3),
                          ),
                          child: const Icon(Icons.photo_camera_rounded,
                              size: 16, color: AppColors.paper),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _editName(context, ref, auth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(context.l10n.tr('perfil_greeting', {'name': name}),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displayMedium),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_rounded,
                          size: 18, color: AppColors.walnutMuted),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(auth.email ?? context.l10n.tr('perfil_guest'),
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Stats — IntrinsicHeight + stretch deixa os 3 cards com a mesma altura.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _StatCard(value: '0', label: context.l10n.tr('perfil_stat_lessons_completed'))),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(value: '0', label: context.l10n.tr('perfil_stat_posts'))),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(value: '0', label: context.l10n.tr('perfil_stat_likes'))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _PremiumBanner(),
          const SizedBox(height: 24),

          Text(context.l10n.tr('perfil_settings'), style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          _SettingTile(
            icon: Icons.notifications_none_rounded,
            title: context.l10n.tr('perfil_tile_notifications_title'),
            subtitle: context.l10n.tr('perfil_tile_notifications_subtitle'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NotificacoesPage()),
            ),
          ),
          _SettingTile(
            icon: Icons.favorite_border,
            title: context.l10n.tr('perfil_tile_favorites_title'),
            subtitle: context.l10n.tr('perfil_tile_favorites_subtitle'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SavedLessonsPage()),
            ),
          ),
          _SettingTile(
            icon: Icons.help_outline_rounded,
            title: context.l10n.tr('perfil_tile_help_title'),
            subtitle: context.l10n.tr('perfil_tile_help_subtitle'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AjudaPage()),
            ),
          ),
          _SettingTile(
            icon: Icons.logout_rounded,
            title: context.l10n.tr('perfil_tile_signout_title'),
            subtitle: context.l10n.tr('perfil_tile_signout_subtitle'),
            onTap: () => _confirmSignOut(context, ref, auth),
          ),
          _SettingTile(
            icon: Icons.delete_forever_outlined,
            title: context.l10n.tr('perfil_tile_delete_title'),
            subtitle: context.l10n.tr('perfil_tile_delete_subtitle'),
            danger: true,
            onTap: () => _confirmDelete(context, ref, auth),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              ref.watch(appVersionProvider).maybeWhen(
                    data: (v) => context.l10n.tr('perfil_version', {'v': v}),
                    orElse: () => 'StitchMind',
                  ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(
      BuildContext context, WidgetRef ref, FirebaseAuthService auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.peachSoft,
        title: Text(context.l10n.tr('perfil_signout_dialog_title')),
        content: Text(context.l10n.tr('perfil_signout_dialog_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(context.l10n.tr('perfil_cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(context.l10n.tr('perfil_signout_confirm'))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(subscriptionServiceProvider).logOut();
      await auth.signOut();
    }
    // O router redireciona para /login automaticamente (refreshListenable).
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, FirebaseAuthService auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.peachSoft,
        title: Text(context.l10n.tr('perfil_delete_dialog_title')),
        content: Text(context.l10n.tr('perfil_delete_dialog_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(context.l10n.tr('perfil_cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coralDeep),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(context.l10n.tr('perfil_delete_confirm')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    // Spinner bloqueante enquanto apaga.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.coral),
      ),
    );
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final rootNav = Navigator.of(context, rootNavigator: true);
    var spinnerOpen = true;
    void closeSpinner() {
      if (spinnerOpen) {
        spinnerOpen = false;
        rootNav.pop();
      }
    }
    try {
      // 1) Apaga dados de aplicação no backend (token ainda válido).
      await ref.read(apiClientProvider).delete('/v1/auth/me');
      // Fecha o spinner ANTES de excluir do Firebase: esse delete dispara o
      // authStateChanges → redirect para /login. Se o pop do spinner acontecer
      // junto com a troca de rota, o navigator entra em conflito (tela preta).
      closeSpinner();
      // 2) Apaga o usuário do Firebase (reautentica se preciso) → vai p/ /login.
      await auth.deleteFirebaseUser();
      // 3) Reseta a identidade do RevenueCat (volta a anônimo).
      await ref.read(subscriptionServiceProvider).logOut();
    } catch (e) {
      closeSpinner(); // fecha o spinner se ainda aberto
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is AuthFailure
              ? e.message
              : l10n.tr('perfil_delete_error')),
          backgroundColor: AppColors.coralDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, FirebaseAuthService auth) async {
    final controller =
        TextEditingController(text: auth.displayName?.trim() ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.peachSoft,
        title: Text(context.l10n.tr('perfil_name_dialog_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            counterText: '',
            hintText: context.l10n.tr('perfil_name_dialog_hint'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(context.l10n.tr('perfil_cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
              child: Text(context.l10n.tr('perfil_save'))),
        ],
      ),
    );
    if (value == null || value.isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(profileServiceProvider).updateName(value);
      messenger.showSnackBar(SnackBar(content: Text(l10n.tr('perfil_name_updated'))));
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.tr('perfil_name_error')),
        backgroundColor: AppColors.coralDeep,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _changePhoto(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.peachSoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: AppColors.coral),
              title: Text(context.l10n.tr('perfil_photo_take')),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library_rounded, color: AppColors.coral),
              title: Text(context.l10n.tr('perfil_photo_gallery')),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final file = await ImagePipeline.pick(source, maxWidth: 1024, quality: 85);
    if (file == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final rootNav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.coral),
      ),
    );
    try {
      await ref.read(profileServiceProvider).uploadAvatar(file);
      rootNav.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.tr('perfil_photo_updated'))));
    } catch (_) {
      rootNav.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.tr('perfil_photo_error')),
        backgroundColor: AppColors.coralDeep,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

/// Banner de assinatura: leva ao paywall (soft) ou mostra "Premium ativo".
class _PremiumBanner extends ConsumerWidget {
  const _PremiumBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionServiceProvider);
    return ListenableBuilder(
      listenable: sub,
      builder: (context, _) {
        final active = sub.isSubscribed;
        final l10n = context.l10n;
        // Mesmo visual do banner de compra da home (OfferBanner). No estado
        // "premium ativo" some o botão de CTA (não há o que comprar).
        return OfferBanner(
          onTap: active ? null : () => context.push('/paywall'),
          showCta: !active,
          title: active
              ? l10n.tr('perfil_premium_active_title')
              : l10n.tr('perfil_premium_cta_title'),
          subtitle: active
              ? l10n.tr('perfil_premium_active_subtitle')
              : l10n.tr('perfil_premium_cta_subtitle'),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 28)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.icon, required this.title, required this.subtitle, this.onTap, this.danger = false});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppColors.coralDeep : AppColors.coral;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.hairline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: danger ? AppColors.coralSoft : AppColors.peach,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: danger ? AppColors.coralDeep : null)),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.walnutMuted),
            ]),
          ),
        ),
      ),
    );
  }
}
