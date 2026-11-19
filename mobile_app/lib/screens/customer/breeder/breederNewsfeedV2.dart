// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../constants/constants.dart';
import '../../../services/api_service.dart';
import '../../common/profileScreen.dart';
import '../klasrumScreen.dart';
import 'breederCreatePost.dart';
import 'breederPostDetails.dart';
import 'breederSearchInterface.dart';
import 'breederViewProfile.dart';

/// Newsfeed content displayed below the shared Klasrum header and tabs.
///
/// Each post may contain `authorName`, `postedLabel`, `title`, `body`,
/// `mediaUrl`, `reactionCount`, and `commentCount` values.
class BreederNewsfeedV2 extends StatefulWidget {
  const BreederNewsfeedV2({
    super.key,
    required this.posts,
  });

  final List<Map<String, dynamic>> posts;

  @override
  State<BreederNewsfeedV2> createState() => _BreederNewsfeedV2State();
}

class _BreederNewsfeedV2State extends State<BreederNewsfeedV2> {
  String _query = '';
  String? _userName;
  late final List<Map<String, dynamic>> _posts = List.of(widget.posts);

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final name = await ApiService.getUserName();
      if (mounted) setState(() => _userName = name);
    } catch (_) {
      // Keep the breeder fallback if the saved profile name is unavailable.
    }
  }

  String _searchText(dynamic value) {
    if (value == null) return '';
    if (value is Map) return value.values.map(_searchText).join(' ');
    if (value is Iterable) return value.map(_searchText).join(' ');
    return value.toString().toLowerCase();
  }

  List<Map<String, dynamic>> get _filteredPosts {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _posts;
    return _posts.where((post) {
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

  Future<void> _openCreatePost() async {
    final result = await Navigator.of(context).push<BreederCreatePostResult>(
      MaterialPageRoute(builder: (_) => const BreederCreatePost()),
    );
    if (!mounted || result == null) return;
    if (result.isDraft) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved.')),
      );
      return;
    }

    setState(() {
      _posts.insert(0, {
        'authorName': _userName?.trim().isNotEmpty == true ? _userName : 'You',
        'postedLabel': 'Just now',
        'title': result.title,
        'body': result.body,
        'localMediaPath': result.media?.path,
        'reactionCount': 0,
        'commentCount': 0,
      });
    });
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(hideBottomNavigation: true),
      ),
    );
  }

  void _openKlasrumProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BreederViewProfile(
          posts: _posts,
          displayName: _userName,
        ),
      ),
    );
  }

  void _openBreederSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BreederSearchInterface()),
    );
  }

  void _openArticles() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const KlasrumScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = _filteredPosts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGreenHeader(context),
        _buildContentTabs(),
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
                  const SizedBox(width: 8),
                  _buildProfileButton(context),
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
              const SizedBox(width: 8),
              Material(
                color: AppColors.brandPrimary,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _openCreatePost,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(Icons.add, size: 21, color: Colors.white),
                  ),
                ),
              ),
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

  Widget _buildContentTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: _openArticles,
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.article_outlined,
                          size: 13, color: Color(0xFF92959B)),
                      SizedBox(width: 5),
                      Text('Articles',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF777A82))),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi, size: 13, color: Colors.white),
                      SizedBox(width: 5),
                      Text('Newsfeed',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreenHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      color: AppColors.brandPrimary,
      padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openProfile,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child:
                        Icon(Icons.person, color: Colors.grey[600], size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Kumusta!',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        Text(
                          _userName?.trim().isNotEmpty == true
                              ? _userName!
                              : 'Breeder',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SvgPicture.asset(
            'assets/icons/Crate.svg',
            height: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          const SizedBox(width: 14),
          SvgPicture.asset(
            'assets/icons/chat.svg',
            height: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    return Material(
      color: const Color(0xE6FFFFFF),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _openKlasrumProfile,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, size: 14, color: Color(0xFF4056A1)),
              SizedBox(width: 5),
              Text(
                'View Profile',
                style: TextStyle(
                  color: Color(0xFF4056A1),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 5),
              Icon(Icons.chevron_right, size: 15, color: Color(0xFF4056A1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsfeedPostCard extends StatefulWidget {
  const _NewsfeedPostCard({required this.post});

  final Map<String, dynamic> post;

  @override
  State<_NewsfeedPostCard> createState() => _NewsfeedPostCardState();
}

class _NewsfeedPostCardState extends State<_NewsfeedPostCard> {
  late bool _liked;
  late int _reactionCount;
  late int _commentCount;
  final List<String> _localComments = [];
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _liked = widget.post['liked'] == true || widget.post['is_liked'] == true;
    _reactionCount = _asInt(
      widget.post['reactionCount'] ?? widget.post['reactions_count'],
    );
    _commentCount = _asInt(
      widget.post['commentCount'] ?? widget.post['comments_count'],
    );
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _reactionCount += _liked ? 1 : -1;
    });
  }

  void _addComment(String value) {
    final comment = value.trim();
    if (comment.isEmpty) return;
    setState(() {
      _commentCount++;
      _localComments.add(comment);
    });
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  String _text(String key, [String fallback = '']) {
    final value = widget.post[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String? _mediaUrl() {
    final directUrl =
        _text('mediaUrl').isNotEmpty ? _text('mediaUrl') : _text('media_url');
    if (directUrl.isNotEmpty) return directUrl;

    final media = widget.post['media'];
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
    final localMediaPath = widget.post['localMediaPath']?.toString();
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BreederPostDetails(
              post: {
                ...widget.post,
                'reactionCount': _reactionCount,
                'commentCount': _commentCount,
                'liked': _liked,
                'comments': [
                  ...((widget.post['comments'] is List)
                      ? widget.post['comments'] as List
                      : const []),
                  ..._localComments,
                ],
              },
            ),
          ),
        );
      },
      child: Container(
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
                          if (widget.post['canFollow'] == true) ...[
                            const SizedBox(width: 8),
                            const Text(
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
                child: localMediaPath != null && localMediaPath.isNotEmpty
                    ? Image.file(
                        File(localMediaPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: Color(0xFFC8C8C8)),
                      )
                    : mediaUrl == null
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
                InkWell(
                  onTap: _toggleLike,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Icon(
                      _liked ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: _liked ? Colors.red : Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(_compactCount(_reactionCount),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(width: 10),
                Icon(Icons.chat_bubble, size: 13, color: Colors.grey[600]),
                const SizedBox(width: 3),
                Text(
                  _compactCount(_commentCount),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: TextField(
                      controller: _commentController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _addComment,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Add Comment',
                        hintStyle:
                            TextStyle(fontSize: 11, color: Colors.grey[600]),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF0F0F0),
                        suffixIcon: IconButton(
                          onPressed: () => _addComment(_commentController.text),
                          icon: const Icon(Icons.send, size: 14),
                          color: AppColors.brandPrimary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_localComments.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final comment in _localComments)
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You  ',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      Expanded(
                        child: Text(
                          comment,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
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
