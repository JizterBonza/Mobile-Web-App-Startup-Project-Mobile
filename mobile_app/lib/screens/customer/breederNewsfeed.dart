import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/constants.dart';
import 'breeder/breederSearchInterface.dart';

/// Newsfeed content displayed below the shared Klasrum header and tabs.
///
/// Each post may contain `authorName`, `postedLabel`, `title`, `body`,
/// `mediaUrl`, `reactionCount`, and `commentCount` values.
class BreederNewsfeed extends StatefulWidget {
  const BreederNewsfeed({
    super.key,
    required this.posts,
    this.onAddPost,
  });

  final List<Map<String, dynamic>> posts;
  final VoidCallback? onAddPost;

  @override
  State<BreederNewsfeed> createState() => _BreederNewsfeedState();
}

class _BreederNewsfeedState extends State<BreederNewsfeed> {
  String _query = '';

  String _searchText(dynamic value) {
    if (value == null) return '';
    if (value is Map) return value.values.map(_searchText).join(' ');
    if (value is Iterable) return value.map(_searchText).join(' ');
    return value.toString().toLowerCase();
  }

  List<Map<String, dynamic>> get _filteredPosts {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.posts;
    return widget.posts.where((post) {
      final content = [
        post['authorName'],
        post['author_name'],
        post['title'],
        post['body'],
        post['description'],
        post['details'],
        post['breeder'],
      ].map(_searchText).join(' ');
      return content.contains(query);
    }).toList();
  }

  void _openBreederSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BreederSearchInterface(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = _filteredPosts;
    final onAddPost = widget.onAddPost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/klasrum-icon.svg',
                          height: 18,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'KLASRUM',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: Colors.grey[900],
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Learn with Klasmeyt',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    readOnly: true,
                    onTap: _openBreederSearch,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search gamefarms...',
                      hintStyle:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                      prefixIcon:
                          Icon(Icons.search, size: 16, color: Colors.grey[500]),
                      prefixIconConstraints: const BoxConstraints(minWidth: 34),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              if (onAddPost != null) ...[
                const SizedBox(width: 8),
                Material(
                  color: AppColors.brandPrimary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onAddPost,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.add, color: Colors.white, size: 21),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (posts.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  Icon(Icons.wifi, size: 28, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    _query.isEmpty ? 'No news posts yet' : 'No matching posts',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
            child: Column(
              children: [
                for (final post in posts) ...[
                  _NewsfeedPostCard(post: post),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
      ],
    );
  }

}

class _NewsfeedPostCard extends StatelessWidget {
  const _NewsfeedPostCard({required this.post});

  final Map<String, dynamic> post;

  String _text(String key, [String fallback = '']) {
    final value = post[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String? _mediaUrl() {
    final directUrl =
        _text('mediaUrl').isNotEmpty ? _text('mediaUrl') : _text('media_url');
    if (directUrl.isNotEmpty) return directUrl;

    final media = post['media'];
    if (media is List && media.isNotEmpty && media.first is Map) {
      final first = Map<String, dynamic>.from(media.first as Map);
      final url = first['url']?.toString().trim() ?? '';
      if (url.isNotEmpty) return url;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authorName = _text('authorName', 'Klasmeyt member');
    final title = _text('title');
    final body = _text('body', _text('description'));
    final postedLabel = _text('postedLabel', 'Recently');
    final mediaUrl = _mediaUrl();
    final reactionCount = post['reactionCount'] ?? post['reactions_count'] ?? 0;
    final commentCount = post['commentCount'] ?? post['comments_count'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFE5E7EB),
                child: Icon(Icons.person, size: 18, color: Colors.grey[500]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (post['canFollow'] == true) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Follow',
                            style: TextStyle(
                              color: AppColors.brandPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      postedLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_horiz, size: 18, color: Colors.grey[500]),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: AspectRatio(
              aspectRatio: 1.55,
              child: mediaUrl == null
                  ? const ColoredBox(color: Color(0xFFC8C8C8))
                  : Image.network(
                      mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: Color(0xFFC8C8C8)),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.favorite, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 3),
              Text(
                _compactCount(reactionCount),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chat_bubble, size: 13, color: Colors.grey[600]),
              const SizedBox(width: 3),
              Text(
                _compactCount(commentCount),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 22,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Add Comment',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _compactCount(dynamic value) {
    if (value is num && value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value?.toString() ?? '0';
  }
}
