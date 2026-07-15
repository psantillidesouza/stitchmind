import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_state.dart';
import '../../../core/media/image_pipeline.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/community.dart';
import '../../providers/platform_providers.dart';

class PublishPostPage extends ConsumerStatefulWidget {
  const PublishPostPage({super.key});

  @override
  ConsumerState<PublishPostPage> createState() => _PublishPostPageState();
}

class _PublishPostPageState extends ConsumerState<PublishPostPage> {
  File? _image;
  final _caption = TextEditingController();
  final _yarn = TextEditingController();
  final _hook = TextEditingController();
  String _type = 'finished';
  String? _category;
  String? _difficulty;
  bool _accepted = AppState.communityGuidelinesAccepted;
  bool _publishing = false;

  @override
  void dispose() {
    _caption.dispose();
    _yarn.dispose();
    _hook.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePipeline.pick(source);
    if (file != null && mounted) setState(() => _image = file);
  }

  Future<void> _publish() async {
    if (_image == null || !_accepted || _publishing) return;
    setState(() => _publishing = true);
    try {
      await ref.read(communityRepositoryProvider).publish(
            _image!,
            _caption.text,
            postType: _type,
            category: _category,
            difficulty: _difficulty,
            yarn: _yarn.text,
            hook: _hook.text,
          );
      await AppState.markCommunityGuidelinesAccepted();
      await ref.read(communityFeedProvider.notifier).refresh();
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Shared! 🧶')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _publishing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPublish = _image != null && _accepted && !_publishing;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.walnut,
        title: const Text('Share your work',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _imageArea(),
          const SizedBox(height: 16),
          TextField(
            controller: _caption,
            maxLength: 600,
            maxLines: 3,
            decoration: _input('Write a caption (optional)…'),
          ),
          const SizedBox(height: 4),
          _label('Type'),
          Row(
            children: [
              for (final e in CommunityMeta.types.entries)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SelChip(
                      label: e.value,
                      selected: _type == e.key,
                      onTap: () => setState(() => _type = e.key),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _label('Category'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in CommunityMeta.categories.entries)
                _SelChip(
                  label: e.value,
                  selected: _category == e.key,
                  onTap: () => setState(
                      () => _category = _category == e.key ? null : e.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _label('Difficulty'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in CommunityMeta.difficulties.entries)
                _SelChip(
                  label: e.value,
                  selected: _difficulty == e.key,
                  onTap: () => setState(
                      () => _difficulty = _difficulty == e.key ? null : e.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(controller: _yarn, decoration: _input('Yarn (optional)')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(controller: _hook, decoration: _input('Hook / needle')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _guidelines(),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.coral,
                disabledBackgroundColor: AppColors.linen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
              ),
              onPressed: canPublish ? _publish : null,
              child: _publishing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Share',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.paper,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.hairline)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.hairline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.coral)),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.walnut)),
      );

  Widget _imageArea() {
    if (_image != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
                aspectRatio: 1, child: Image.file(_image!, fit: BoxFit.cover)),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => setState(() => _image = null),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: _pickButton(Icons.photo_camera_rounded, 'Camera', ImageSource.camera)),
        const SizedBox(width: 12),
        Expanded(child: _pickButton(Icons.photo_library_rounded, 'Gallery', ImageSource.gallery)),
      ],
    );
  }

  Widget _pickButton(IconData icon, String label, ImageSource source) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: () => _pick(source),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: AppColors.coral),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.walnut)),
          ],
        ),
      ),
    );
  }

  Widget _guidelines() {
    return InkWell(
      onTap: () => setState(() => _accepted = !_accepted),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _accepted,
              activeColor: AppColors.coral,
              onChanged: (v) => setState(() => _accepted = v ?? false),
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'I agree to the community guidelines: no offensive content, '
                  'nudity, spam or harassment. Inappropriate content may be '
                  'removed and the account suspended.',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.walnutSoft),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelChip extends StatelessWidget {
  const _SelChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.coral : AppColors.paper,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(color: selected ? AppColors.coral : AppColors.hairline),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : AppColors.walnutSoft)),
      ),
    );
  }
}
