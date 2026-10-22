import 'dart:io';
import 'package:flutter/material.dart';
import '../../../constants/constants.dart';

class BreederPostDetails extends StatefulWidget {
  const BreederPostDetails({super.key, required this.post});
  final Map<String, dynamic> post;

  @override
  State<BreederPostDetails> createState() => _BreederPostDetailsState();
}

class _BreederPostDetailsState extends State<BreederPostDetails> {
  final _commentController = TextEditingController();
  late bool _liked;
  late int _likeCount;
  late final List<String> _comments;

  @override
  void initState() {
    super.initState();
    _liked = widget.post['liked'] == true || widget.post['is_liked'] == true;
    final count = widget.post['reactionCount'] ??
        widget.post['reactions_count'] ??
        widget.post['likes_count'];
    _likeCount = count is num
        ? count.toInt()
        : int.tryParse(count?.toString() ?? '') ?? 0;
    final raw = widget.post['comments'];
    _comments = raw is List
        ? raw.map(_commentText).where((e) => e.isNotEmpty).toList()
        : <String>[];
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _commentText(dynamic value) {
    if (value is Map)
      return (value['comment'] ?? value['body'] ?? value['content'] ?? '')
          .toString()
          .trim();
    return value?.toString().trim() ?? '';
  }

  String _text(List<String> keys, [String fallback = '']) {
    for (final key in keys) {
      final value = widget.post[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  void _addComment() {
    final value = _commentController.text.trim();
    if (value.isEmpty) return;
    setState(() => _comments.add(value));
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final author = _text(['authorName', 'author_name', 'name'], 'Klasmeyt');
    final posted = _text(['postedLabel', 'created_at'], 'Recently');
    final title = _text(['title']);
    final body = _text(['body', 'description', 'details']);
    final localPath = _text(['localMediaPath']);
    final mediaUrl = _text(['mediaUrl', 'media_url']);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Klasrum Post',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(context).height * .34,
                  child: localPath.isNotEmpty
                      ? Image.file(File(localPath), fit: BoxFit.cover)
                      : mediaUrl.isNotEmpty
                          ? Image.network(mediaUrl, fit: BoxFit.cover)
                          : const ColoredBox(color: Color(0xFFC7C7C7)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const CircleAvatar(
                              radius: 12,
                              backgroundColor: Color(0xFFE5E5E5),
                              child: Icon(Icons.person,
                                  size: 15, color: Colors.white)),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700))),
                          Text(posted,
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF92959B))),
                          const SizedBox(width: 6),
                          const Icon(Icons.more_vert,
                              size: 14, color: Color(0xFF8D9096)),
                        ]),
                        if (title.isNotEmpty) ...[
                          const SizedBox(height: 9),
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(body,
                              style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  color: Color(0xFF62656B))),
                        ],
                        const SizedBox(height: 8),
                        Row(children: [
                          InkWell(
                            onTap: () => setState(() {
                              _liked = !_liked;
                              _likeCount += _liked ? 1 : -1;
                            }),
                            child: Row(children: [
                              Icon(
                                  _liked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 14,
                                  color: _liked
                                      ? Colors.red
                                      : const Color(0xFF6E7279)),
                              const SizedBox(width: 4),
                              Text('$_likeCount',
                                  style: const TextStyle(
                                      fontSize: 10, color: Color(0xFF777A80))),
                            ]),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.mode_comment_outlined,
                              size: 13, color: Color(0xFF6E7279)),
                          const SizedBox(width: 4),
                          Text('${_comments.length}',
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF777A80))),
                        ]),
                      ]),
                ),
                const Divider(height: 1, color: Color(0xFFE8E8E8)),
                const Padding(
                    padding: EdgeInsets.fromLTRB(12, 9, 12, 6),
                    child: Text('Comments',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700))),
                if (_comments.isEmpty)
                  const Padding(
                      padding: EdgeInsets.fromLTRB(12, 4, 12, 16),
                      child: Text('No comments yet. Be the first to comment.',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF92959B))))
                else
                  for (var i = 0; i < _comments.length; i++)
                    _buildComment(_comments[i], i),
              ],
            ),
          ),
          _buildCommentComposer(),
        ],
      ),
    );
  }

  Widget _buildComment(String comment, int index) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
            radius: 11,
            backgroundColor: const Color(0xFFE2E4E9),
            child: Text(index.isEven ? 'JD' : 'SJ',
                style: const TextStyle(fontSize: 9, color: Color(0xFF51545B)))),
        const SizedBox(width: 7),
        Expanded(
            child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: const Color(0xFFF0F1F4),
              borderRadius: BorderRadius.circular(12)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                index >= 2
                    ? 'You'
                    : (index.isEven ? 'Juan Doe' : 'Sarah Jenkins'),
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(comment,
                style: const TextStyle(
                    fontSize: 10, height: 1.3, color: Color(0xFF666A72))),
            const SizedBox(height: 5),
            const Text('Like    Reply    Just now',
                style: TextStyle(fontSize: 9, color: Color(0xFF8E929A))),
          ]),
        )),
      ]),
    );
  }

  Widget _buildCommentComposer() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
          child: Row(children: [
            Expanded(
                child: TextField(
              controller: _commentController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(),
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                hintStyle:
                    const TextStyle(fontSize: 11, color: Color(0xFF858890)),
                filled: true,
                fillColor: const Color(0xFFF0F0F0),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
              ),
            )),
            IconButton(
                onPressed: _addComment,
                icon: const Icon(Icons.send,
                    size: 18, color: AppColors.brandPrimary)),
          ]),
        ),
      );
}
