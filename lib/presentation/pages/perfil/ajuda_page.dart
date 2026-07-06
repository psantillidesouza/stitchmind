import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Central de ajuda — perguntas frequentes do app.
class AjudaPage extends StatelessWidget {
  const AjudaPage({super.key});

  List<(String, String)> _faqs(BuildContext c) => [
        (
          c.l10n.tr('ajuda_faq_favorite_q'),
          c.l10n.tr('ajuda_faq_favorite_a'),
        ),
        (
          c.l10n.tr('ajuda_faq_profile_q'),
          c.l10n.tr('ajuda_faq_profile_a'),
        ),
        (
          c.l10n.tr('ajuda_faq_photo_analysis_q'),
          c.l10n.tr('ajuda_faq_photo_analysis_a'),
        ),
        (
          c.l10n.tr('ajuda_faq_data_usage_q'),
          c.l10n.tr('ajuda_faq_data_usage_a'),
        ),
        (
          c.l10n.tr('ajuda_faq_offline_counter_q'),
          c.l10n.tr('ajuda_faq_offline_counter_a'),
        ),
        (
          c.l10n.tr('ajuda_faq_account_q'),
          c.l10n.tr('ajuda_faq_account_a'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tr('ajuda_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text(context.l10n.tr('ajuda_heading'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(context.l10n.tr('ajuda_intro'),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ..._faqs(context).map((f) => _FaqTile(question: f.$1, answer: f.$2)),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});
  final String question, answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.coral,
          collapsedIconColor: AppColors.walnutMuted,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(question,
              style: Theme.of(context).textTheme.titleMedium),
          children: [
            Text(answer,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}
