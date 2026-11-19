import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../constants/constants.dart';

class BreederCreatePostResult {
  const BreederCreatePostResult({
    required this.title,
    required this.body,
    required this.media,
    required this.isDraft,
  });

  final String title;
  final String body;
  final XFile? media;
  final bool isDraft;
}

class BreederCreatePost extends StatefulWidget {
  const BreederCreatePost({super.key});

  @override
  State<BreederCreatePost> createState() => _BreederCreatePostState();
}

class _BreederCreatePostState extends State<BreederCreatePost> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _imagePicker = ImagePicker();
  XFile? _media;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      final file = await _imagePicker.pickMedia();
      if (mounted && file != null) setState(() => _media = file);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not select the media file.')),
      );
    }
  }

  void _submit({required bool isDraft}) {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (!isDraft && title.isEmpty && body.isEmpty && _media == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title, post content, or media.')),
      );
      return;
    }

    Navigator.of(context).pop(
      BreederCreatePostResult(
        title: title,
        body: body,
        media: _media,
        isDraft: isDraft,
      ),
    );
  }

  bool get _mediaIsImage {
    final mimeType = _media?.mimeType?.toLowerCase() ?? '';
    if (mimeType.startsWith('image/')) return true;
    final path = _media?.path.toLowerCase() ?? '';
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF202124),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF62666B),
            child: Icon(Icons.arrow_back, size: 18, color: Colors.white),
          ),
        ),
        titleSpacing: 4,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Post',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              'Share an update, photo, or video with your followers',
              style: TextStyle(fontSize: 9, color: Color(0xFF64676B)),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration('Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bodyController,
                  minLines: 12,
                  maxLines: 16,
                  textCapitalization: TextCapitalization.sentences,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: _inputDecoration('Write your content here...'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Additional Media',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Optional',
                      style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildMediaPicker(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _submit(isDraft: true),
                  icon: const Icon(Icons.save_outlined, size: 15),
                  label: const Text('Save Draft'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF50545A),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE1E3E6)),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _submit(isDraft: false),
                  icon: const Icon(Icons.send, size: 14),
                  label: const Text('Post'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 10, color: Colors.grey[500]),
      contentPadding: const EdgeInsets.all(10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E4E7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E4E7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.brandPrimary),
      ),
    );
  }

  Widget _buildMediaPicker() {
    final media = _media;
    return Container(
      width: double.infinity,
      height: 104,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        border: Border.all(color: const Color(0xFFE8EBEF)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: media == null
          ? InkWell(
              onTap: _pickMedia,
              borderRadius: BorderRadius.circular(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      size: 20, color: Colors.grey[600]),
                  const SizedBox(height: 4),
                  Text(
                    'Upload image or video',
                    style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                  ),
                  Text(
                    'Select one image or video',
                    style: TextStyle(fontSize: 8, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  FilledButton.tonalIcon(
                    onPressed: _pickMedia,
                    icon: const Icon(Icons.attach_file, size: 11),
                    label: const Text('Select File'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      minimumSize: const Size(0, 23),
                      textStyle: const TextStyle(fontSize: 8),
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                if (_mediaIsImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(File(media.path), fit: BoxFit.cover),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_file_outlined,
                            size: 28, color: AppColors.brandPrimary),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36),
                          child: Text(
                            media.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    onPressed: () => setState(() => _media = null),
                    icon: const Icon(Icons.close, size: 16),
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
    );
  }
}
