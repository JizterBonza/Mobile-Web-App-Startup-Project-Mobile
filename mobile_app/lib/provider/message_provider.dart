import 'dart:io';

import 'package:flutter/material.dart';

import '../models/messageModel.dart';
import '../services/message_service.dart';
import '../services/reverb_service.dart';

/// Shared state for customer conversations and the open thread.
class MessageProvider with ChangeNotifier {
  final MessageService _service = MessageService();
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

  /// Connects Reverb and subscribes to known conversation channels.
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

  /// Messages list is visible — refresh the list when a realtime event arrives.
  void watchConversations() {
    _conversationWatchers++;
    startLiveUpdates();
  }

  void unwatchConversations() {
    if (_conversationWatchers > 0) _conversationWatchers--;
  }

  Future<void> _syncRealtimeSubscriptions() async {
    if (!_liveEnabled) return;
    final ids = _conversations
        .map((item) => item.id)
        .where((id) => id != null)
        .map((id) => id.toString())
        .toSet();
    final activeId = _activeThread?.conversation.id;
    if (activeId != null) ids.add(activeId.toString());
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
        final unchanged = silent &&
            payload.unreadCount == _unreadCount &&
            _sameConversationList(payload.conversations, _conversations);
        _conversations = payload.conversations;
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

  /// GET /api/messages/unread-count — lightweight badge refresh.
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
        _activeThread = _mergeThread(result['data'] as ConversationThread);
        _error = null;
        _markConversationRead(_activeThread!.conversation.id);
        _syncConversationPreview(_activeThread!);
        if (_liveEnabled) {
          await _reverb.subscribeConversation(_activeThread!.conversation.id);
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

  /// Starts or resumes a conversation with a shop. Empty body is allowed.
  Future<bool> startOrResumeConversation({
    required dynamic shopId,
    String? body,
    List<File> attachments = const [],
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.startConversation(
        shopId: shopId,
        body: body,
        attachments: attachments,
      );
      if (result['success'] == true && result['data'] != null) {
        _activeThread = _mergeThread(result['data'] as ConversationThread);
        _error = null;
        _markConversationRead(_activeThread!.conversation.id);
        _syncConversationPreview(_activeThread!);
        if (_liveEnabled) {
          await _reverb.subscribeConversation(_activeThread!.conversation.id);
        }
        return true;
      }

      await fetchConversations(silent: true);
      ConversationModel? existing;
      for (final conversation in _conversations) {
        if (conversation.shopId?.toString() == shopId.toString()) {
          existing = conversation;
          break;
        }
      }
      if (existing != null) {
        return loadConversation(existing.id);
      }

      _error = result['message'] ?? 'Failed to start conversation';
      return false;
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
  }) async {
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.sendMessage(
        conversationId: conversationId,
        body: body,
        attachments: attachments,
      );
      if (result['success'] == true && result['data'] != null) {
        _activeThread = _mergeThread(result['data'] as ConversationThread);
        _error = null;
        _syncConversationPreview(_activeThread!, bumpTimestamp: true);
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

  Future<bool> refreshActiveThread() async {
    final id = _activeThread?.conversation.id;
    if (id == null) return false;

    try {
      final result = await _service.fetchConversation(id);
      if (result['success'] == true && result['data'] != null) {
        final incoming = _mergeThread(result['data'] as ConversationThread);
        if (_sameThread(incoming, _activeThread)) return true;
        _activeThread = incoming;
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
    if (notify) notifyListeners();
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
    _conversations[index] = current.copyWith(unread: false);
    if (_unreadCount > 0) _unreadCount -= 1;
  }

  ConversationThread _mergeThread(ConversationThread incoming) {
    final previous = _activeThread;
    if (incoming.shop != null || previous?.shop == null) return incoming;
    return incoming.copyWith(shop: previous!.shop);
  }

  bool _sameThread(ConversationThread incoming, ConversationThread? current) {
    if (current == null) return false;
    if (incoming.conversation.lastSeen != current.conversation.lastSeen) {
      return false;
    }
    if (incoming.messages.length != current.messages.length) return false;
    if (incoming.messages.isEmpty) return true;
    final nextLast = incoming.messages.last;
    final prevLast = current.messages.last;
    return nextLast.id?.toString() == prevLast.id?.toString() &&
        nextLast.status == prevLast.status &&
        nextLast.body == prevLast.body;
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
      if (a.lastMessage != b.lastMessage) return false;
      if (a.unread != b.unread) return false;
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
    for (final message in thread.messages.reversed) {
      if (message.isDate) continue;
      if (message.body.isNotEmpty) {
        lastMessage = message.body;
        break;
      }
    }

    _upsertConversation(
      ConversationModel(
        id: id,
        shopId: thread.shop?.id ?? existing?.shopId,
        shopName: thread.shopName.isNotEmpty
            ? thread.shopName
            : (existing?.shopName ?? ''),
        lastMessage: lastMessage,
        lastMessageAt: bumpTimestamp
            ? DateTime.now()
            : (existing?.lastMessageAt ?? DateTime.now()),
        unread: false,
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
