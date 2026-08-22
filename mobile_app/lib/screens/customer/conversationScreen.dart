import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/constants.dart';
import '../../models/messageModel.dart';
import '../../provider/message_provider.dart';
import '../../services/message_service.dart';
import '../../utils/customer_nav.dart';
import '../../utils/snackbar_helper.dart';
import 'messageProductPickerScreen.dart';
import 'productDetailScreen.dart';

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
  static const Color _outgoingBubble = Color(0xFFD8F3E7);

  final TextEditingController _bodyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _pendingAttachments = [];
  bool _attachMenuOpen = false;

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

  void _toggleAttachMenu() {
    if (_remainingSlots <= 0 && !_attachMenuOpen) {
      SnackbarHelper.showWarning(
        context,
        'You can attach up to ${MessageService.maxAttachments} files',
      );
      return;
    }
    setState(() => _attachMenuOpen = !_attachMenuOpen);
    if (_attachMenuOpen) {
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _onAttachAction(Future<void> Function() action) async {
    if (_remainingSlots <= 0) {
      SnackbarHelper.showWarning(
        context,
        'You can attach up to ${MessageService.maxAttachments} files',
      );
      return;
    }
    await action();
    if (mounted) setState(() => _attachMenuOpen = false);
  }

  Future<File> _materializePickedFile(XFile picked) async {
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Selected file is empty');
    }

    var ext = picked.path.split('.').last.toLowerCase();
    if (!MessageService.allowedExtensions.contains(ext)) {
      ext = 'jpg';
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/msg_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _pickFromCamera() async {
    try {
      final photo = await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      _addFiles([await _materializePickedFile(photo)]);
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
      final files = <File>[];
      for (final photo in photos) {
        files.add(await _materializePickedFile(photo));
      }
      _addFiles(files);
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not open gallery: $e');
      }
    }
  }

  void _openProductPicker() {
    setState(() => _attachMenuOpen = false);
    final shopId = widget.shopId ?? _messageProvider?.activeThread?.shop?.id;
    if (shopId == null) {
      SnackbarHelper.showWarning(context, 'No shop to browse');
      return;
    }
    final conversationId = widget.conversationId ??
        _messageProvider?.activeThread?.conversation.id;
    Navigator.push(
      context,
      customerFadeRoute(
        MessageProductPickerScreen(
          shopId: shopId,
          conversationId: conversationId,
          shopName: widget.shopName,
        ),
      ),
    ).then((_) {
      if (mounted) _scrollToBottom();
    });
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
        rejected.add(
            '${file.path.split(Platform.pathSeparator).last}: .$ext not allowed');
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
      _pendingAttachments.clear();
      _attachMenuOpen = false;
      setState(() {});
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

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFFF7F7F7),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              toolbarHeight: 64,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.white,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
              title: _buildHeader(title, lastSeen),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child:
                    Divider(height: 1, thickness: 1, color: Colors.grey[200]),
              ),
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
                            if (provider.activeThread?.conversation.id !=
                                null) {
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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

  Widget _buildHeader(String title, String lastSeen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF3F4F6),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.chevron_left,
                  size: 26,
                  color: Color(0xFF4B5563),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SvgPicture.asset(
            'assets/icons/Store.svg',
            width: 40,
            height: 40,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                if (lastSeen.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    lastSeen,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(MessageModel message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          message.label.isNotEmpty ? message.label : ' ',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _formatMessageTime(String raw) {
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      final local = parsed.toLocal();
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = local.hour >= 12 ? 'PM' : 'AM';
      return '$hour.$minute $period';
    }
    return raw.replaceFirstMapped(
      RegExp(r'(\d{1,2}):(\d{2})'),
      (match) => '${match[1]}.${match[2]}',
    );
  }

  bool _isReadStatus(String status) {
    final value = status.toLowerCase();
    return value.contains('read') || value.contains('seen');
  }

  Widget _buildBubble(MessageModel message) {
    final mine = _isMine(message);
    final time = _formatMessageTime(message.time);
    final isProduct = message.isProduct && message.product != null;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isProduct ? 0.82 : 0.78),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (time.isNotEmpty || mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      if (mine) ...[
                        if (time.isNotEmpty) const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: _isReadStatus(message.status)
                              ? AppColors.primaryGreen
                              : Colors.grey[400],
                        ),
                      ],
                    ],
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: mine ? _outgoingBubble : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(mine ? 16 : 4),
                    topRight: const Radius.circular(16),
                    bottomLeft: const Radius.circular(16),
                    bottomRight: Radius.circular(mine ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: mine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (isProduct) _buildProductSnapshot(message.product!),
                    if (message.attachments.isNotEmpty) ...[
                      if (isProduct) const SizedBox(height: 8),
                      ...message.attachments.map(
                        (attachment) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildAttachment(attachment, mine),
                        ),
                      ),
                    ],
                    if (message.displayText.isNotEmpty) ...[
                      if (isProduct || message.attachments.isNotEmpty)
                        const SizedBox(height: 8),
                      Text(
                        message.displayText,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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

  Widget _buildProductSnapshot(MessageProductSnapshot product) {
    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 72,
              child: product.imageUrl == null || product.imageUrl!.isEmpty
                  ? Container(
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.primaryGreen,
                      ),
                    )
                  : Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                if (product.variationLabel != null &&
                    product.variationLabel!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    product.variationLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          if (product.priceLabel != null &&
                              product.priceLabel!.isNotEmpty)
                            Text(
                              product.priceLabel!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          if (product.hasDiscount)
                            Text(
                              product.originalPriceLabel!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: product.id == null
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                customerFadeRoute(
                                  ProductDetailScreen(productId: product.id),
                                ),
                              );
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: const BorderSide(color: AppColors.primaryGreen),
                        minimumSize: const Size(56, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Buy',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
    );
  }

  Widget _fileChip(MessageAttachmentModel attachment, bool mine) {
    return InkWell(
      onTap: () => _openAttachment(attachment),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? Colors.white.withOpacity(0.55) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 18,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                attachment.name.isNotEmpty ? attachment.name : 'Attachment',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
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
    const iconGrey = Color(0xFFA8A8A8);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingAttachments.isNotEmpty) ...[
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
            const SizedBox(height: 8),
          ],
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: isSending ? null : _toggleAttachMenu,
                  icon: _attachMenuOpen
                      ? const Icon(Icons.close, size: 22, color: Color(0xFF7E7E7E))
                      : SvgPicture.asset(
                          'assets/icons/Add.svg',
                          width: 16,
                          height: 16,
                        ),
                ),
                Expanded(
                  child: TextField(
                    controller: _bodyController,
                    enabled: !isSending,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: MessageService.maxBodyLength,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Type Here...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: isSending || !_canSend ? null : _send,
                  icon: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Opacity(
                          opacity: _canSend ? 1 : 0.4,
                          child: SvgPicture.asset(
                            'assets/icons/Send.svg',
                            width: 20,
                            height: 19,
                          ),
                        ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _attachMenuOpen
                ? Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildAttachTile(
                          icon: SvgPicture.asset(
                            'assets/icons/Gallery.svg',
                            width: 22,
                            height: 22,
                          ),
                          label: 'Gallery',
                          onTap: isSending
                              ? null
                              : () => _onAttachAction(_pickFromGallery),
                        ),
                        _buildAttachTile(
                          icon: SvgPicture.asset(
                            'assets/icons/Camera.svg',
                            width: 22,
                            height: 18,
                          ),
                          label: 'Camera',
                          onTap: isSending
                              ? null
                              : () => _onAttachAction(_pickFromCamera),
                        ),
                        _buildAttachTile(
                          icon: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 24,
                            color: iconGrey,
                          ),
                          label: 'Products',
                          onTap: isSending ? null : _openProductPicker,
                        ),
                        _buildAttachTile(
                          icon: SvgPicture.asset(
                            'assets/icons/orders.svg',
                            width: 18,
                            height: 20,
                            colorFilter: const ColorFilter.mode(
                              iconGrey,
                              BlendMode.srcIn,
                            ),
                          ),
                          label: 'Orders',
                          onTap: isSending
                              ? null
                              : () => setState(() => _attachMenuOpen = false),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachTile({
    required Widget icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFA8A8A8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
