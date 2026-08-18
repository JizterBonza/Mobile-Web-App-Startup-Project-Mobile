import 'dart:async';
import 'dart:convert';

import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/foundation.dart';

import '../constants/constants.dart';
import '../utils/api_endpoints.dart';
import 'api_service.dart';

typedef ShopMessageSentHandler = void Function(
  dynamic conversationId,
  Map<String, dynamic> data,
);

class _ChannelBinding {
  final PrivateChannel channel;
  final StreamSubscription<ChannelReadEvent> eventSub;

  _ChannelBinding({required this.channel, required this.eventSub});
}

/// Laravel Reverb (Pusher-compatible) client for customer messaging.
class ReverbService {
  static const channelPrefix = 'private-shop-conversation.';
  static const eventName = 'shop.message.sent';

  PusherChannelsClient? _client;
  StreamSubscription<void>? _connectionSub;
  final Map<String, _ChannelBinding> _channels = {};
  final Set<String> _desiredIds = {};
  ShopMessageSentHandler? onShopMessageSent;
  bool _connecting = false;
  bool _connected = false;

  bool get isConnected => _connected;

  String _channelName(String conversationId) =>
      '$channelPrefix$conversationId';

  Future<Map<String, String>> _authHeaders() async {
    final token = await ApiService.getToken();
    return {
      'Authorization': 'Bearer ${token ?? ''}',
      'Accept': 'application/json',
    };
  }

  Future<void> connect() async {
    if (_connected || _connecting) return;
    final key = AppConfig.reverbAppKey;
    if (key.isEmpty) {
      debugPrint('DEBUG [Reverb] REVERB_APP_KEY missing; skip connect');
      return;
    }
    final host = AppConfig.reverbHost;
    if (host.isEmpty) {
      debugPrint('DEBUG [Reverb] REVERB_HOST missing; skip connect');
      return;
    }

    _connecting = true;
    try {
      final options = PusherChannelsOptions.fromHost(
        scheme: AppConfig.reverbWsScheme,
        host: host,
        key: key,
        port: AppConfig.reverbPort,
        shouldSupplyMetadataQueries: true,
        metadata: const PusherChannelsOptionsMetadata.byDefault(),
      );

      debugPrint(
        'DEBUG [Reverb] connecting ${AppConfig.reverbWsScheme}://$host:${AppConfig.reverbPort}',
      );

      _client = PusherChannelsClient.websocket(
        options: options,
        connectionErrorHandler: (exception, trace, refresh) {
          debugPrint('DEBUG [Reverb] connection error: $exception');
          _connected = false;
          refresh();
        },
      );

      _connectionSub = _client!.onConnectionEstablished.listen((_) {
        _connected = true;
        debugPrint('DEBUG [Reverb] connected');
        _resubscribeAll();
      });

      await _client!.connect();
    } catch (e) {
      debugPrint('DEBUG [Reverb] connect failed: $e');
      _connected = false;
    } finally {
      _connecting = false;
    }
  }

  Future<void> disconnect() async {
    _connected = false;
    _connecting = false;
    for (final id in _channels.keys.toList()) {
      await _dropChannel(id);
    }
    await _connectionSub?.cancel();
    _connectionSub = null;
    try {
      await _client?.disconnect();
    } catch (_) {}
    try {
      _client?.dispose();
    } catch (_) {}
    _client = null;
  }

  Future<void> subscribeConversation(dynamic id) async {
    if (id == null) return;
    final conversationId = id.toString();
    if (conversationId.isEmpty) return;
    _desiredIds.add(conversationId);
    await _ensureChannel(conversationId);
  }

  Future<void> syncSubscriptions(Iterable<dynamic> ids) async {
    final next = ids
        .where((id) => id != null && id.toString().isNotEmpty)
        .map((id) => id.toString())
        .toSet();
    _desiredIds
      ..clear()
      ..addAll(next);

    final current = _channels.keys.toSet();
    for (final id in current.difference(_desiredIds)) {
      await _dropChannel(id);
    }
    for (final id in _desiredIds) {
      await _ensureChannel(id);
    }
  }

  Future<void> _resubscribeAll() async {
    for (final id in _desiredIds) {
      await _ensureChannel(id, force: true);
    }
  }

  Future<void> _ensureChannel(String conversationId, {bool force = false}) async {
    final client = _client;
    if (client == null || !_connected) return;

    if (_channels.containsKey(conversationId) && !force) {
      _channels[conversationId]!.channel.subscribeIfNotUnsubscribed();
      return;
    }

    if (force) {
      await _dropChannel(conversationId);
    }

    final headers = await _authHeaders();
    final channel = client.privateChannel(
      _channelName(conversationId),
      authorizationDelegate:
          EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
        authorizationEndpoint: Uri.parse(ApiEndpoints.broadcastingAuth),
        headers: headers,
      ),
      forceCreateNewInstance: force,
    );

    final eventSub = channel.bind(eventName).listen((event) {
      _handleShopMessageSent(conversationId, event);
    });

    _channels[conversationId] = _ChannelBinding(
      channel: channel,
      eventSub: eventSub,
    );
    channel.subscribe();
    debugPrint('DEBUG [Reverb] subscribed ${_channelName(conversationId)}');
  }

  Future<void> _dropChannel(String conversationId) async {
    final binding = _channels.remove(conversationId);
    if (binding == null) return;
    await binding.eventSub.cancel();
    try {
      binding.channel.unsubscribe();
    } catch (_) {}
  }

  void _handleShopMessageSent(String fallbackId, ChannelReadEvent event) {
    final data = event.tryGetDataAsMap() ?? _decodeData(event.data);
    final conversationId = data['conversation_id'] ??
        data['conversationId'] ??
        (data['conversation'] is Map ? data['conversation']['id'] : null) ??
        _idFromChannelName(event.channelName) ??
        fallbackId;

    debugPrint(
      'DEBUG [Reverb] $eventName conversation=$conversationId',
    );
    onShopMessageSent?.call(conversationId, data);
  }

  Map<String, dynamic> _decodeData(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  String? _idFromChannelName(String? name) {
    if (name == null || !name.startsWith(channelPrefix)) return null;
    final id = name.substring(channelPrefix.length);
    return id.isEmpty ? null : id;
  }
}
