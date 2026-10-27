
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/messageModel.dart';
import '../services/message_service.dart';
import '../services/reverb_service.dart';

/// Shared state for customer conversations and the open thread.
class MessageProvider with ChangeNotifier {
  MessageProvider({MessageService? messageService})
      : _service = messageService ?? MessageService();

  final MessageService _service;
  final ReverbService _reverb = ReverbService();

  List<ConversationModel> _conversations = [];
  ConversationThread? _activeThread;
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  int _unreadCount = 0;
  bool _liveEnabled = false;
  bool _eventInFlight = false;
  int _conversationWatchers = 0;

  List<ConversationModel> get conversations => _conversations;
  ConversationThread? get activeThread => _activeThread;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  Future<void> startLiveUpdates() async {
    _liveEnabled = true;
    _reverb.onShopMessageSent = _onShopMessageSent;

    await _reverb.connect();
    await fetchUnreadCount();
    await fetchConversations(silent: true);
    await _syncRealtimeSubscriptions();

    final activeId = _activeThread?.conversation.id;
    if (activeId != null) {
      await _reverb.subscribeConversation(activeId);
    }
  }

  Future<void> pauseLiveUpdates() async {
    await _reverb.disconnect();
  }

  Future<void> stopLiveUpdates() async {
    _liveEnabled = false;
    _reverb.onShopMessageSent = null;
    await _reverb.disconnect();
  }

  void watchConversations() {
    _conversationWatchers++;
    startLiveUpdates();
  }

  void unwatchConversations() {
    if (_conversationWatchers > 0) {
      _conversationWatchers--;
    }
  }

  Future<void> _syncRealtimeSubscriptions() async {
    if (!_liveEnabled) return;

    final ids = _conversations
        .map((item) => item.id)
        .where((id) => id != null)
        .map((id) => id.toString())
        .toSet();

    final activeId = _activeThread?.conversation.id;
    if (activeId != null) {
      ids.add(activeId.toString());
    }

    await _reverb.syncSubscriptions(ids);
  }

  Future<void> _onShopMessageSent(
    dynamic conversationId,
    Map<String, dynamic> data,
  ) async {
    if (_eventInFlight) return;

    _eventInFlight = true;

    try {
      final activeId = _activeThread?.conversation.id?.toString();

      if (activeId != null &&
          conversationId != null &&
          activeId == conversationId.toString()) {
        await refreshActiveThread();
      }

      await fetchUnreadCount();

      if (_conversations.isNotEmpty || _conversationWatchers > 0) {
        await fetchConversations(silent: true);
        await _syncRealtimeSubscriptions();
      }
    } finally {
      _eventInFlight = false;
    }
  }

  Future<bool> fetchConversations({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final result = await _service.fetchConversations();

      if (result['success'] == true && result['data'] != null) {
        final payload = result['data'] as ConversationListResponse;
        final conversations = payload.conversations.map((item) {
          ConversationModel? previous;
          for (final existing in _conversations) {
            if (existing.id?.toString() == item.id?.toString()) {
              previous = existing;
              break;
            }
          }
          if (previous == null) return item;
          if (item.farmId != null || item.shopId != null) {
            return item.copyWith(
                avatarUrl: item.avatarUrl ?? previous.avatarUrl);
          }
          if (previous.farmId == null) {
            return item.copyWith(
                avatarUrl: item.avatarUrl ?? previous.avatarUrl);
          }
          return item.copyWith(
            farmId: previous.farmId,
            shopName:
                item.shopName.isNotEmpty ? item.shopName : previous.shopName,
            avatarUrl: item.avatarUrl ?? previous.avatarUrl,
          );
        }).toList();
        final unchanged = silent &&
            payload.unreadCount == _unreadCount &&
            _sameConversationList(conversations, _conversations);
        _conversations = conversations;
        _unreadCount = payload.unreadCount;
        _error = null;

        if (_liveEnabled) {
          await _syncRealtimeSubscriptions();
        }

        if (!silent) {
          _isLoading = false;
          notifyListeners();
        } else if (!unchanged) {
          notifyListeners();
        }

        return true;
      }

      _error = result['message'] ?? 'Failed to fetch conversations';

      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }

      return false;
    } catch (e) {
      _error = e.toString();

      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }

      return false;
    }
  }

  Future<bool> fetchUnreadCount() async {
    try {
      final result = await _service.fetchUnreadCount();

      if (result['success'] == true && result['data'] != null) {
        final next = result['data'] as int;

        if (_unreadCount != next) {
          _unreadCount = next;
          notifyListeners();
        }

        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> loadConversation(dynamic conversationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.fetchConversation(conversationId);

      if (result['success'] == true && result['data'] != null) {
        // Use the thread returned by the API without carrying over
        // shop details from the previously opened conversation.
        _activeThread = result['data'] as ConversationThread;
        _error = null;

        _markConversationRead(_activeThread!.conversation.id);
        _syncConversationPreview(_activeThread!);

        if (_liveEnabled) {
          await _reverb.subscribeConversation(
            _activeThread!.conversation.id,
          );
        }

        return true;
      }

      _error = result['message'] ?? 'Failed to load conversation';
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Starts or resumes a conversation with the selected shop.
  Future<bool> startOrResumeConversation({
    required dynamic shopId,
    String? body,
    List<File> attachments = const [],
    dynamic itemId,
  }) async {
    final requestedShopId = shopId.toString().trim();

    if (requestedShopId.isEmpty || requestedShopId == '0') {
      _error = 'Invalid shop ID.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;

    // Prevent stale shop details from the previous conversation.
    _activeThread = null;
    notifyListeners();

    try {
      final result = await _service.startConversation(
        shopId: shopId,
        body: body,
        attachments: attachments,
        itemId: itemId,
      );

      if (result['success'] == true && result['data'] != null) {
        final incoming = result['data'] as ConversationThread;

        // This model exposes shop details through incoming.shop.
        final returnedShopId = incoming.shop?.id;

        if (returnedShopId != null &&
            returnedShopId.toString().trim() != requestedShopId) {
          _error =
              'The conversation does not match the selected shop.';
        } else {
          _activeThread = incoming;
          _error = null;

          _markConversationRead(_activeThread!.conversation.id);
          _syncConversationPreview(
            _activeThread!,
            bumpTimestamp: itemId != null,
          );

          if (_liveEnabled) {
            await _reverb.subscribeConversation(
              _activeThread!.conversation.id,
            );
          }

          return true;
        }
      }

      // Look for an existing conversation for this exact shop only.
      await fetchConversations(silent: true);

      ConversationModel? existing;

      for (final conversation in _conversations) {
        if (conversation.shopId?.toString().trim() == requestedShopId) {
          existing = conversation;
          break;
        }
      }

      if (existing?.id != null) {
        return await loadConversation(existing!.id);
      }

      _activeThread = null;
      _error ??= result['message'] ?? 'Failed to start conversation';
      return false;
    } catch (e) {
      _activeThread = null;
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startOrResumeFarmConversation({
    required dynamic farmId,
    String? farmName,
    String? body,
    List<File> attachments = const [],
    dynamic itemId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.startFarmConversation(
        farmId,
        body: body,
        attachments: attachments,
        itemId: itemId,
      );
      if (result['success'] != true || result['data'] is! ConversationThread) {
        _error = result['message'] ?? 'Failed to start farm conversation';
        return false;
      }
      var thread = result['data'] as ConversationThread;
      if (thread.conversation.id == null) {
        _error = 'Farm conversation has no ID';
        return false;
      }
      if (thread.farm == null &&
          farmName != null &&
          farmName.trim().isNotEmpty) {
        thread = thread.copyWith(
          farm: MessageShopInfo(id: farmId, shopName: farmName.trim()),
        );
      }
      _activeThread = _mergeThread(thread);
      _markConversationRead(_activeThread!.conversation.id);
      _syncConversationPreview(
        _activeThread!,
        bumpTimestamp: itemId != null ||
            (body?.trim().isNotEmpty ?? false) ||
            attachments.isNotEmpty,
      );
      if (_liveEnabled) {
        await _reverb.subscribeConversation(_activeThread!.conversation.id);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage({
    required dynamic conversationId,
    String? body,
    List<File> attachments = const [],
    dynamic itemId,
  }) async {
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.sendMessage(
        conversationId: conversationId,
        body: body,
        attachments: attachments,
        itemId: itemId,
      );

      if (result['success'] == true && result['data'] != null) {
        final incoming = result['data'] as ConversationThread;
        _activeThread = _mergeThread(incoming);
        _error = null;

        _syncConversationPreview(
          _activeThread!,
          bumpTimestamp: true,
        );

        return true;
      }

      _error = result['message'] ?? 'Failed to send message';
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool> sendProductMessage({
    required dynamic shopId,
    dynamic conversationId,
    required dynamic itemId,
  }) async {
    if (conversationId != null) {
      return sendMessage(
        conversationId: conversationId,
        itemId: itemId,
      );
    }

    return startOrResumeConversation(
      shopId: shopId,
      itemId: itemId,
    );
  }

  Future<bool> refreshActiveThread() async {
    final id = _activeThread?.conversation.id;
    if (id == null) return false;

    try {
      final result = await _service.fetchConversation(id);

      if (result['success'] == true && result['data'] != null) {
        final incoming = result['data'] as ConversationThread;

        if (_sameThread(incoming, _activeThread)) {
          return true;
        }

        _activeThread = _mergeThread(incoming);
        _error = null;
        _syncConversationPreview(_activeThread!);
        notifyListeners();

        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  void clearActiveThread({bool notify = true}) {
    _activeThread = null;

    if (notify) {
      notifyListeners();
    }
  }

  void clear() {
    stopLiveUpdates();
    _conversationWatchers = 0;
    _conversations = [];
    _activeThread = null;
    _unreadCount = 0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  void _markConversationRead(dynamic id) {
    if (id == null) return;

    final index = _conversations.indexWhere(
      (item) => item.id?.toString() == id.toString(),
    );

    if (index < 0) return;

    final current = _conversations[index];
    if (!current.unread) return;

    _conversations[index] = current.copyWith(
      unread: false,
      unreadCount: 0,
    );

    if (_unreadCount > 0) {
      _unreadCount -= 1;
    }
  }

  ConversationThread _mergeThread(ConversationThread incoming) {
    final previous = _activeThread;
    if (previous == null ||
        previous.conversation.id?.toString() !=
            incoming.conversation.id?.toString()) return incoming;
    if (incoming.shop != null || incoming.farm != null) return incoming;
    return incoming.copyWith(
      shop: previous.shop,
      farm: previous.farm,
    );
  }

  bool _sameThread(
    ConversationThread incoming,
    ConversationThread? current,
  ) {
    if (current == null) return false;

    if (incoming.conversation.lastSeen != current.conversation.lastSeen) {
      return false;
    }

    if (incoming.messages.length != current.messages.length) {
      return false;
    }

    if (incoming.messages.isEmpty) return true;

    final nextLast = incoming.messages.last;
    final prevLast = current.messages.last;

    return nextLast.id?.toString() == prevLast.id?.toString() &&
        nextLast.status == prevLast.status &&
        nextLast.displayText == prevLast.displayText &&
        nextLast.attachments.length == prevLast.attachments.length;
  }

  bool _sameConversationList(
    List<ConversationModel> incoming,
    List<ConversationModel> current,
  ) {
    if (incoming.length != current.length) return false;

    for (var i = 0; i < incoming.length; i++) {
      final a = incoming[i];
      final b = current[i];

      if (a.id?.toString() != b.id?.toString()) return false;
      if (a.shopName != b.shopName || a.farmId != b.farmId) return false;
      if (a.avatarUrl != b.avatarUrl) return false;
      if (a.lastMessage != b.lastMessage) return false;
      if (a.unread != b.unread) return false;
      if (a.unreadCount != b.unreadCount) return false;
      if (a.lastMessageSide != b.lastMessageSide) return false;
      if (a.lastMessageAt != b.lastMessageAt) return false;
    }

    return true;
  }

  void _syncConversationPreview(
    ConversationThread thread, {
    bool bumpTimestamp = false,
  }) {
    final id = thread.conversation.id;
    if (id == null) return;

    ConversationModel? existing;

    for (final item in _conversations) {
      if (item.id?.toString() == id.toString()) {
        existing = item;
        break;
      }
    }

    String lastMessage = existing?.lastMessage ?? '';
    String? lastMessageSide = existing?.lastMessageSide;

    for (final message in thread.messages.reversed) {
      if (message.isDate) continue;

      if (message.displayText.isEmpty &&
          message.attachments.isEmpty &&
          !message.isProduct) {
        continue;
      }

      final preview = message.previewText;

      if (preview.isNotEmpty) {
        lastMessage = preview;
      }

      if (message.side.isNotEmpty) {
        lastMessageSide = message.side;
      }

      break;
    }

    if (bumpTimestamp) {
      lastMessageSide = 'outgoing';
    }

    _upsertConversation(
      ConversationModel(
        id: id,
        shopId: thread.shop?.id ?? existing?.shopId,
        farmId: thread.farm?.id ?? existing?.farmId,
        shopName: thread.displayName.isNotEmpty
            ? thread.displayName
            : (existing?.shopName ?? ''),
        avatarUrl: thread.avatarUrl ?? existing?.avatarUrl,
        lastMessage: lastMessage,
        lastMessageAt: bumpTimestamp
            ? DateTime.now().toUtc()
            : (existing?.lastMessageAt ?? DateTime.now().toUtc()),
        unread: false,
        unreadCount: 0,
        lastMessageSide: lastMessageSide,
      ),
    );
  }

  void _upsertConversation(ConversationModel conversation) {
    _conversations.removeWhere(
      (item) => item.id?.toString() == conversation.id?.toString(),
    );

    _conversations.insert(0, conversation);
  }
}
