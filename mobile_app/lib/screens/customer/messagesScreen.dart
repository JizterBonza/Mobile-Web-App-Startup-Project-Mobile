import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/constants.dart';
import '../../models/messageModel.dart';
import '../../provider/message_provider.dart';
import '../../services/api_service.dart';
import '../../utils/customer_nav.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import 'conversationScreen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _isGuest = true;
  MessageProvider? _messageProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGuestState();
      _fetchConversations();
      _messageProvider?.watchConversations();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messageProvider ??= Provider.of<MessageProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _messageProvider?.unwatchConversations();
    super.dispose();
  }

  Future<void> _loadGuestState() async {
    try {
      final token = await ApiService.getToken();
      if (!mounted) return;
      setState(() {
        _isGuest = token == null || token.isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _isGuest = true);
    }
  }

  Future<void> _fetchConversations() async {
    await Provider.of<MessageProvider>(context, listen: false)
        .fetchConversations();
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[timestamp.month - 1]} ${timestamp.day}';
  }

  void _openConversation(ConversationModel conversation) {
    Navigator.push(
      context,
      customerFadeRoute(
        ConversationScreen(
          conversationId: conversation.id,
          shopId: conversation.shopId,
          shopName: conversation.shopName,
        ),
      ),
    ).then((_) {
      if (mounted) {
        Provider.of<MessageProvider>(context, listen: false)
            .fetchConversations(silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(
          'Messages',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[700]),
      ),
      body: Consumer<MessageProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.conversations.isEmpty) {
            return const ListRowsSkeleton(count: 8);
          }

          if (provider.error != null && provider.conversations.isEmpty) {
            return _buildErrorState(provider.error!);
          }

          if (provider.conversations.isEmpty) {
            return RefreshIndicator(
              onRefresh: _fetchConversations,
              color: AppColors.primaryGreen,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height - 220,
                    child: const EmptyStateWidget(
                      icon: Icons.chat_bubble_outline,
                      message: 'No conversations yet',
                      subtitle: 'Message a shop to start a conversation',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _fetchConversations,
            color: AppColors.primaryGreen,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.conversations.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.grey[200],
                indent: 76,
              ),
              itemBuilder: (context, index) {
                final conversation = provider.conversations[index];
                return _buildConversationTile(conversation);
              },
            ),
          );
        },
      ),
      bottomNavigationBar: buildCustomerBottomNavigationBar(
        context: context,
        currentIndex: CustomerNavIndex.home,
        isGuest: _isGuest,
        onLoginSuccess: () {
          _loadGuestState();
          _fetchConversations();
        },
      ),
    );
  }

  Widget _buildConversationTile(ConversationModel conversation) {
    final unread = conversation.unread;
    final initial = conversation.shopName.isNotEmpty
        ? conversation.shopName[0].toUpperCase()
        : 'S';
    final preview = conversation.lastMessage.isNotEmpty
        ? conversation.lastMessage
        : 'No messages yet';

    return ListTile(
      onTap: () => _openConversation(conversation),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primaryGreen.withOpacity(0.12),
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      title: Text(
        conversation.shopName.isNotEmpty ? conversation.shopName : 'Shop',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
            color: unread ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTimestamp(conversation.lastMessageAt),
            style: TextStyle(
              fontSize: 12,
              fontWeight: unread ? FontWeight.w700 : FontWeight.normal,
              color: unread ? AppColors.primaryGreen : Colors.grey[500],
            ),
          ),
          if (unread) ...[
            const SizedBox(height: 6),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              'Failed to load messages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchConversations,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
