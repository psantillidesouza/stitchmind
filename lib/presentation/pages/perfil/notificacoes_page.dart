import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Preferências de notificação, guardadas localmente.
/// O usuário escolhe se quer lembretes e em que horário; as escolhas persistem
/// entre sessões e ficam prontas para alimentar o agendamento de lembretes.
class NotificacoesPage extends StatefulWidget {
  const NotificacoesPage({super.key});

  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends State<NotificacoesPage> {
  static const _kDaily = 'notif_daily_v1';
  static const _kHour = 'notif_hour_v1';
  static const _kTips = 'notif_tips_v1';
  static const _kCommunity = 'notif_community_v1';

  bool _loading = true;
  bool _daily = true;
  int _hour = 19;
  bool _tips = true;
  bool _community = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _daily = p.getBool(_kDaily) ?? true;
      _hour = p.getInt(_kHour) ?? 19;
      _tips = p.getBool(_kTips) ?? true;
      _community = p.getBool(_kCommunity) ?? true;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDaily, _daily);
    await p.setInt(_kHour, _hour);
    await p.setBool(_kTips, _tips);
    await p.setBool(_kCommunity, _community);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: 0),
      helpText: context.l10n.tr('notif_time_picker_help'),
    );
    if (picked != null) {
      setState(() => _hour = picked.hour);
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tr('notif_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.coral))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                _Card(
                  child: Column(
                    children: [
                      _SwitchRow(
                        icon: Icons.self_improvement_rounded,
                        title: context.l10n.tr('notif_daily_title'),
                        subtitle: context.l10n.tr('notif_daily_subtitle'),
                        value: _daily,
                        onChanged: (v) {
                          setState(() => _daily = v);
                          _save();
                        },
                      ),
                      if (_daily) ...[
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          leading: const Icon(Icons.schedule_rounded,
                              color: AppColors.coral),
                          title: Text(context.l10n.tr('notif_time_label')),
                          trailing: Text(
                            '${_hour.toString().padLeft(2, '0')}:00',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          onTap: _pickTime,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Card(
                  child: Column(
                    children: [
                      _SwitchRow(
                        icon: Icons.lightbulb_outline_rounded,
                        title: context.l10n.tr('notif_tips_title'),
                        subtitle: context.l10n.tr('notif_tips_subtitle'),
                        value: _tips,
                        onChanged: (v) {
                          setState(() => _tips = v);
                          _save();
                        },
                      ),
                      const Divider(height: 1, indent: 56),
                      _SwitchRow(
                        icon: Icons.favorite_outline_rounded,
                        title: context.l10n.tr('notif_community_title'),
                        subtitle: context.l10n.tr('notif_community_subtitle'),
                        value: _community,
                        onChanged: (v) {
                          setState(() => _community = v);
                          _save();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    context.l10n.tr('notif_footer_note'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Icon(icon, color: AppColors.coral),
      activeThumbColor: AppColors.coral,
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      value: value,
      onChanged: onChanged,
    );
  }
}
