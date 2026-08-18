import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/constants.dart';
import '../../models/messageModel.dart';
import '../../provider/message_provider.dart';
import '../../services/message_service.dart';
import '../../utils/snackbar_helper.dart';

class ConversationScreen extends StatefulWidget {
  final dynamic conversationId;
  final dynamic shopId;
  final String? shopName;

  const ConversationScreen({
    super.key,
    this.conversationId,
    this.shopId,
    this.shopName,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _bodyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _pendingAttachments = [];

  bool _didInitialLoad = false;
  int _lastMessageCount = 0;
  MessageProvider? _messageProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    await _loadThread();
    if (!mounted) return;
    _messageProvider?.startLiveUpdates();
    _lastMessageCount = _messageProvider?.activeThread?.messages.length ?? 0;
  }

  Future<void> _loadThread() async {
    final provider = Provider.of<MessageProvider>(context, listen: false);
    bool success;
    if (widget.conversationId != null) {
      success = await provider.loadConversation(widget.conversationId);
    } else if (widget.shopId != null) {
      success = await provider.startOrResumeConversation(shopId: widget.shopId);
    } else {
      success = false;
      provider.clearActiveThread();
    }

    if (!mounted) return;
    setState(() => _didInitialLoad = true);
    _lastMessageCount = provider.activeThread?.messages.length ?? 0;
    if (success) {
      _scrollToBottom();
    } else if (provider.error != null) {
      SnackbarHelper.showError(context, provider.error!);
    }
  }

  void _onMessagesChanged() {
    final count = _messageProvider?.activeThread?.messages.length ?? 0;
    if (count > _lastMessageCount && _didInitialLoad) {
      _scrollToBottom();
    }
    _lastMessageCount = count;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isMine(MessageModel message) => message.isOutgoing;

  int get _remainingSlots =>
      MessageService.maxAttachments - _pendingAttachments.length;

  Future<void> _showAttachSheet() async {
    if (_remainingSlots <= 0) {
      SnackbarHelper.showWarning(
        context,
        'You can attach up to ${MessageService.maxAttachments} files',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('Files'),
                subtitle: const Text('Images, MP4, PDF, DOCX'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickFiles();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final photo = await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      _addFiles([File(photo.path)]);
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not open camera: $e');
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final photos = await _imagePicker.pickMultiImage();
      if (photos.isEmpty) return;
      _addFiles(photos.map((item) => File(item.path)).toList());
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not open gallery: $e');
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: MessageService.allowedExtensions.toList(),
      );
      if (result == null || result.files.isEmpty) return;
      final files = <File>[];
      for (final item in result.files) {
        if (item.path != null) files.add(File(item.path!));
      }
      _addFiles(files);
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not pick files: $e');
      }
    }
  }

  void _addFiles(List<File> files) {
    if (files.isEmpty) return;
    final rejected = <String>[];
    var added = 0;

    for (final file in files) {
      if (_pendingAttachments.length >= MessageService.maxAttachments) {
        rejected.add('Limit of ${MessageService.maxAttachments} files reached');
        break;
      }
      if (!file.existsSync()) {
        rejected.add('File not found');
        continue;
      }
      final ext = file.path.split('.').last.toLowerCase();
      if (!MessageService.allowedExtensions.contains(ext)) {
        rejected.add('${file.path.split(Platform.pathSeparator).last}: .$ext not allowed');
        continue;
      }
      if (file.lengthSync() > MessageService.maxAttachmentBytes) {
        rejected.add(
          '${file.path.split(Platform.pathSeparator).last} exceeds 20MB',
        );
        continue;
      }
      _pendingAttachments.add(file);
      added++;
    }

    if (mounted) {
      setState(() {});
      if (rejected.isNotEmpty) {
        SnackbarHelper.showWarning(context, rejected.first);
      } else if (added > 0) {
        SnackbarHelper.showInfo(context, '$added file(s) attached');
      }
    }
  }

  void _removePending(int index) {
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  bool get _canSend {
    final hasBody = _bodyController.text.trim().isNotEmpty;
    return hasBody || _pendingAttachments.isNotEmpty;
  }

  Future<void> _send() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty && _pendingAttachments.isEmpty) return;
    if (body.length > MessageService.maxBodyLength) {
      SnackbarHelper.showWarning(
        context,
        'Message must not exceed ${MessageService.maxBodyLength} characters',
      );
      return;
    }

    final provider = Provider.of<MessageProvider>(context, listen: false);
    final conversationId =
        provider.activeThread?.conversation.id ?? widget.conversationId;
    final attachments = List<File>.from(_pendingAttachments);

    bool success;
    if (conversationId != null) {
      success = await provider.sendMessage(
        conversationId: conversationId,
        body: body.isEmpty ? null : body,
        attachments: attachments,
      );
    } else if (widget.shopId != null) {
      success = await provider.startOrResumeConversation(
        shopId: widget.shopId,
        body: body.isEmpty ? null : body,
        attachments: attachments,
      );
    } else {
      SnackbarHelper.showError(context, 'No conversation to send to');
      return;
    }

    if (!mounted) return;
    if (success) {
      _bodyController.clear();
      setState(() => _pendingAttachments.clear());
      _scrollToBottom();
    } else if (provider.error != null) {
      SnackbarHelper.showError(context, provider.error!);
    }
  }

  Future<void> _openAttachment(MessageAttachmentModel attachment) async {
    final uri = Uri.tryParse(attachment.resolvedUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not open file: $e');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<MessageProvider>(context, listen: false);
    if (!identical(_messageProvider, provider)) {
      _messageProvider?.removeListener(_onMessagesChanged);
      _messageProvider = provider;
      _messageProvider?.addListener(_onMessagesChanged);
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _scrollController.dispose();
    _messageProvider?.removeListener(_onMessagesChanged);
    _messageProvider?.clearActiveThread(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MessageProvider>(
      builder: (context, provider, _) {
        final thread = provider.activeThread;
        final title = thread?.shopName.isNotEmpty == true
            ? thread!.shopName
            : (widget.shopName?.isNotEmpty == true ? widget.shopName! : 'Chat');
        final lastSeen = thread?.conversation.lastSeen ?? '';
        final isLoading = provider.isLoading && thread == null;

        return Scaffold(
          backgroundColor: AppColors.surfaceLight,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                if (lastSeen.isNotEmpty)
                  Text(
                    lastSeen,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.grey[700]),
          ),
          body: Column(
            children: [
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          if (provider.activeThread?.conversation.id != null) {
                            await provider.refreshActiveThread();
                          } else {
                            await _loadThread();
                          }
                        },
                        color: AppColors.primaryGreen,
                        child: _buildMessageList(thread),
                      ),
              ),
              _buildComposer(provider.isSending),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageList(ConversationThread? thread) {
    final messages = thread?.messages ?? const <MessageModel>[];
    if (_didInitialLoad && messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: const Center(
              child: Text(
                'No messages yet. Say hello!',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        if (message.isDate) {
          return _buildDateSeparator(message);
        }
        return _buildBubble(message);
      },
    );
  }

  Widget _buildDateSeparator(MessageModel message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.label.isNotEmpty ? message.label : ' ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(MessageModel message) {
    final mine = _isMine(message);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? AppColors.primaryGreen : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
            border: mine ? null : Border.all(color: AppColors.borderDefault),
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message.body.isNotEmpty)
                Text(
                  message.body,
                  style: TextStyle(
                    color: mine ? Colors.white : AppColors.textPrimary,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              if (message.attachments.isNotEmpty) ...[
                if (message.body.isNotEmpty) const SizedBox(height: 8),
                ...message.attachments.map(
                  (attachment) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _buildAttachment(attachment, mine),
                  ),
                ),
              ],
              if (message.time.isNotEmpty || message.status.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.time.isNotEmpty)
                      Text(
                        message.time,
                        style: TextStyle(
                          fontSize: 11,
                          color: mine ? Colors.white70 : Colors.grey[500],
                        ),
                      ),
                    if (mine && message.status.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        message.status,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachment(MessageAttachmentModel attachment, bool mine) {
    if (attachment.isImage && attachment.resolvedUrl.isNotEmpty) {
      return GestureDetector(
        onTap: () => _openAttachment(attachment),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            attachment.resolvedUrl,
            width: 180,
            height: 140,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fileChip(attachment, mine),
          ),
        ),
      );
    }
    return _fileChip(attachment, mine);
  }

  Widget _fileChip(MessageAttachmentModel attachment, bool mine) {
    return InkWell(
      onTap: () => _openAttachment(attachment),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: mine
              ? Colors.white.withOpacity(0.15)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 18,
              color: mine ? Colors.white : AppColors.primaryGreen,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                attachment.name.isNotEmpty ? attachment.name : 'Attachment',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: mine ? Colors.white : AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(bool isSending) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingAttachments.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingAttachments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final file = _pendingAttachments[index];
                  final name = file.path.split(Platform.pathSeparator).last;
                  return InputChip(
                    label: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: isSending ? null : () => _removePending(index),
                    deleteIconColor: AppColors.error,
                    backgroundColor: AppColors.surfaceLight,
                  );
                },
              ),
            ),
          if (_pendingAttachments.isNotEmpty) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: isSending ? null : _showAttachSheet,
                icon: const Icon(Icons.attach_file),
                color: AppColors.primaryGreen,
              ),
              Expanded(
                child: TextField(
                  controller: _bodyController,
                  enabled: !isSending,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: MessageService.maxBodyLength,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: isSending || !_canSend ? null : _send,
                icon: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                color: AppColors.primaryGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
