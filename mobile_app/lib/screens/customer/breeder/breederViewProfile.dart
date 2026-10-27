import 'dart:io';

import 'package:flutter/material.dart';

import '../../../constants/constants.dart';
import '../../../services/api_service.dart';
import 'breederCreatePost.dart';
import 'breederPostDetails.dart';

class BreederViewProfile extends StatefulWidget {
  const BreederViewProfile({
    super.key,
    this.posts = const [],
    this.displayName,
  });

  final List<Map<String, dynamic>> posts;
  final String? displayName;

  @override
  State<BreederViewProfile> createState() => _BreederViewProfileState();
}

class _BreederViewProfileState extends State<BreederViewProfile> {
  late final List<Map<String, dynamic>> _posts = List.of(widget.posts);
  String? _name;

  @override
  void initState() {
    super.initState();
    _name = widget.displayName;
    if (_name?.trim().isNotEmpty != true) _loadName();
  }

  Future<void> _loadName() async {
    try {
      final value = await ApiService.getUserName();
      if (mounted && value?.trim().isNotEmpty == true) {
        setState(() => _name = value);
      }
    } catch (_) {
      // Use the default profile title if the account name is unavailable.
    }
  }

  Future<void> _createPost() async {
    final result = await Navigator.of(context).push<BreederCreatePostResult>(
      MaterialPageRoute(builder: (_) => const BreederCreatePost()),
    );
    if (!mounted || result == null || result.isDraft) return;
    setState(() {
      _posts.insert(0, {
        'authorName': _name?.trim().isNotEmpty == true ? _name : 'You',
        'postedLabel': 'Just now',
        'title': result.title,
        'body': result.body,
        'localMediaPath': result.media?.path,
        'reactionCount': 0,
        'commentCount': 0,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileName =
        _name?.trim().isNotEmpty == true ? _name! : 'Gamefarm Name';
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F3),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                const SizedBox(
                  width: double.infinity,
                  height: 160,
                  child: ColoredBox(color: Color(0xFFC7C7C7)),
                ),
                Positioned(
                  top: 14,
                  left: 10,
                  right: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _roundButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                        background: Colors.white,
                        foreground: const Color(0xFF858891),
                      ),
                      _roundButton(
                        icon: Icons.add,
                        onTap: _createPost,
                        background: AppColors.brandPrimary,
                        foreground: Colors.white,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 125),
                  child: _buildProfileCard(profileName),
                ),
              ],
            ),
            const SizedBox(height: 9),
            if (_posts.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 24, 14, 18),
                child: Text(
                  'No posts to show yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF858891)),
                ),
              )
            else
              for (final post in _posts) ...[
                _ProfilePostCard(post: post),
                const SizedBox(height: 6),
              ],
          ],
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color background,
    required Color foreground,
  }) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 16, color: foreground),
        ),
      ),
    );
  }

  Widget _buildProfileCard(String name) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(0, -22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFFE4E6EA),
                  child: Icon(Icons.storefront, size: 28, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified,
                          size: 15, color: Color(0xFF4259A8)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 0),
          _profileInfo(Icons.person_outline, 'Breeders Name / Username'),
          const SizedBox(height: 7),
          _profileInfo(
              Icons.email_outlined, 'sample_email@gmail.com  |  09999999999'),
          const SizedBox(height: 7),
          _profileInfo(Icons.location_on_outlined, 'Farm Address'),
        ],
      ),
    );
  }

  Widget _profileInfo(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF777D89)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Color(0xFF687080)),
          ),
        ),
      ],
    );
  }
}

class _ProfilePostCard extends StatelessWidget {
  const _ProfilePostCard({required this.post});
  final Map<String, dynamic> post;

  String _text(List<String> keys, [String fallback = '']) {
    for (final key in keys) {
      final value = post[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final author = _text(['authorName', 'author_name'], 'Klasmeyt');
    final title = _text(['title']);
    final body = _text(['body', 'description']);
    final time = _text(['postedLabel', 'created_at'], 'Recently');
    final localPath = _text(['localMediaPath']);
    final mediaUrl = _text(['mediaUrl', 'media_url']);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BreederPostDetails(post: post),
      )),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(9)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(
                radius: 11,
                backgroundColor: Color(0xFFE2E3E5),
                child: Icon(Icons.person, size: 12, color: Colors.white)),
            const SizedBox(width: 5),
            Expanded(
                child: Text(author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700))),
            Text(time,
                style: const TextStyle(fontSize: 10, color: Color(0xFF92959B))),
            const SizedBox(width: 5),
            const Icon(Icons.more_vert, size: 12, color: Color(0xFF8D9096)),
          ]),
          const SizedBox(height: 5),
          if (title.isNotEmpty)
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          if (body.isNotEmpty)
            Text(body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Color(0xFF777A82))),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            height: 105,
            child: localPath.isNotEmpty
                ? Image.file(File(localPath), fit: BoxFit.cover)
                : mediaUrl.isNotEmpty
                    ? Image.network(mediaUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: Color(0xFFC7C7C7)))
                    : const ColoredBox(color: Color(0xFFC7C7C7)),
          ),
          const SizedBox(height: 5),
          Row(children: [
            const Icon(Icons.favorite, size: 11, color: Color(0xFF737780)),
            const SizedBox(width: 3),
            Text('${post['reactionCount'] ?? post['reactions_count'] ?? 0}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF777A82))),
            const SizedBox(width: 8),
            const Icon(Icons.mode_comment_outlined,
                size: 10, color: Color(0xFF737780)),
            const SizedBox(width: 3),
            Text('${post['commentCount'] ?? post['comments_count'] ?? 0}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF777A82))),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('Add Comment',
                    style: TextStyle(fontSize: 11, color: Color(0xFF777A82)))),
          ]),
        ]),
      ),
    );
  }
}
