import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/server_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Future<void> _editServerUrl() async {
    final controller = TextEditingController(text: ServerConfig.url);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text('Servidor de IA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cole o endereço do backend (rodando no seu PC).',
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'http://192.168.1.100:8000',
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.walnutMuted,
                ),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aparelho precisa estar na mesma rede WiFi.',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result != null) {
      await ServerConfig.setUrl(result);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(projectsStreamProvider).valueOrNull ?? const [];
    final active =
        all.where((p) => p.status == ProjectStatus.inProgress).length;
    final done =
        all.where((p) => p.status == ProjectStatus.finished).length;
    final analyses = ref.watch(recentAnalysesProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Text(
            'Você',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.linen),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.terracotta,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'P',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.paper,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedro',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '$active em andamento · $done concluídos · '
                        '${analyses.length} análises',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const _Section(title: 'Inteligência artificial'),
          _SettingsTile(
            icon: Icons.dns_outlined,
            title: 'Servidor de IA',
            value: ServerConfig.url,
            onTap: _editServerUrl,
          ),
          const SizedBox(height: 32),
          const _Section(title: 'Preferências'),
          const _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Tema',
            value: 'Automático',
          ),
          const _SettingsTile(
            icon: Icons.language_outlined,
            title: 'Idioma',
            value: 'Português',
          ),
          const _SettingsTile(
            icon: Icons.straighten,
            title: 'Unidades',
            value: 'cm · mm',
          ),
          const SizedBox(height: 32),
          const _Section(title: 'Conta'),
          const _SettingsTile(
            icon: Icons.backup_outlined,
            title: 'Backup',
            value: 'Local',
          ),
          const _SettingsTile(
            icon: Icons.ios_share,
            title: 'Exportar projetos',
          ),
          const SizedBox(height: 32),
          const _Section(title: 'Sobre'),
          const _SettingsTile(
            icon: Icons.info_outline,
            title: 'Versão',
            value: '0.1.0',
          ),
          const _SettingsTile(
            icon: Icons.favorite_outline,
            title: 'Avaliar o app',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: AppColors.terracottaDeep,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.walnutSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.walnutMuted,
            ),
          ],
        ),
      ),
    );
  }
}
