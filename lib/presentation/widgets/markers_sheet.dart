import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/entities.dart';
import '../providers/providers.dart';

class MarkersSheet extends ConsumerStatefulWidget {
  const MarkersSheet({required this.projectId, super.key});
  final String projectId;

  static Future<void> show(BuildContext context, String projectId) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MarkersSheet(projectId: projectId),
    );
  }

  @override
  ConsumerState<MarkersSheet> createState() => _MarkersSheetState();
}

class _MarkersSheetState extends ConsumerState<MarkersSheet> {
  final _row = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _row.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final row = int.tryParse(_row.text.trim());
    if (row == null || row <= 0) return;
    final project = ref.read(projectByIdProvider(widget.projectId));
    if (project == null) return;
    final next = [
      ...project.markers,
      Marker(row: row, note: _note.text.trim()),
    ]..sort((a, b) => a.row.compareTo(b.row));
    await ref
        .read(projectActionsProvider)
        .setMarkers(widget.projectId, next);
    _row.clear();
    _note.clear();
  }

  Future<void> _remove(int index) async {
    final project = ref.read(projectByIdProvider(widget.projectId));
    if (project == null) return;
    final next = [...project.markers]..removeAt(index);
    await ref
        .read(projectActionsProvider)
        .setMarkers(widget.projectId, next);
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectByIdProvider(widget.projectId));
    final markers = project?.markers ?? const [];
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.linen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Marcadores',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Avisa quando você chegar em uma carreira específica '
                  '— ótimo para diminuições e mudanças de cor.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _row,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _inputDecoration('nº'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _note,
                        decoration: _inputDecoration('descrição'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.walnut,
                        foregroundColor: AppColors.paper,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.add),
                      onPressed: _add,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              Expanded(
                child: markers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'nenhum marcador ainda',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        itemCount: markers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _MarkerRow(
                          marker: markers[i],
                          currentRow: project!.currentRow,
                          onDelete: () => _remove(i),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: AppColors.walnutMuted,
        ),
        filled: true,
        fillColor: AppColors.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.linen),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.walnut, width: 1.5),
        ),
      );
}

class _MarkerRow extends StatelessWidget {
  const _MarkerRow({
    required this.marker,
    required this.currentRow,
    required this.onDelete,
  });
  final Marker marker;
  final int currentRow;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final reached = currentRow >= marker.row;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reached ? AppColors.sage : AppColors.linen,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: reached
                  ? AppColors.sage.withValues(alpha: 0.2)
                  : AppColors.linen.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${marker.row}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: reached ? AppColors.sage : AppColors.walnut,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              marker.note.isEmpty ? 'sem descrição' : marker.note,
              style: marker.note.isEmpty
                  ? Theme.of(context).textTheme.bodyMedium
                  : Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.walnutMuted,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
