import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../constants/constants.dart';
import '../../models/messageModel.dart';
import '../../provider/badge_provider.dart';
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
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
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
    'Dec',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
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
    _searchController.dispose();
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

  List<ConversationModel> _filteredConversations(
    List<ConversationModel> conversations,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return conversations;
    return conversations.where((conversation) {
      return conversation.shopName.toLowerCase().contains(query) ||
          conversation.lastMessage.toLowerCase().contains(query);
    }).toList();
  }

  String _formatClock(DateTime timestamp) {
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour.$minute $period';
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final difference = today.difference(date).inDays;

    if (difference == 0) return _formatClock(local);
    if (difference == 1) return 'Yesterday';
    if (difference > 1 && difference < 7) {
      return _weekdays[local.weekday - 1];
    }
    return '${_months[local.month - 1]} ${local.day}';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
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
          title: _buildHeader(),
        ),
        body: Consumer<MessageProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && provider.conversations.isEmpty) {
              return const ListRowsSkeleton(count: 8);
            }

            if (provider.error != null && provider.conversations.isEmpty) {
              return _buildErrorState(provider.error!);
            }

            final conversations =
                _filteredConversations(provider.conversations);

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

            if (conversations.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.search_off,
                message: 'No conversations found',
                subtitle: 'Try a different shop name or message',
              );
            }

            return RefreshIndicator(
              onRefresh: _fetchConversations,
              color: AppColors.primaryGreen,
              child: ListView.separated(
                itemCount: conversations.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey[200],
                ),
                itemBuilder: (context, index) {
                  return _buildConversationTile(conversations[index]);
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
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 12),
          Expanded(child: _buildSearchField()),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Material(
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
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        cursorColor: AppColors.primaryGreen,
        decoration: InputDecoration(
          hintText: 'Search Conversation',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[400]),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: AppColors.primaryGreen),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationTile(ConversationModel conversation) {
    final unread = conversation.unread;
    final preview = conversation.lastMessage.isNotEmpty
        ? conversation.lastMessage
        : 'No messages yet';
    final showCheck = !unread && conversation.lastMessageSide == 'outgoing';
    final badgeLabel =
        BadgeProvider.formatBadgeCount(conversation.displayUnreadCount);

    return InkWell(
      onTap: () => _openConversation(conversation),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/icons/Store.svg',
              width: 52,
              height: 52,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.shopName.isNotEmpty
                        ? conversation.shopName
                        : 'Shop',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTimestamp(conversation.lastMessageAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                    color: unread
                        ? AppColors.primaryGreen
                        : Colors.grey[500],
                  ),
                ),
                if (unread && badgeLabel != null) ...[
                  const SizedBox(height: 6),
                  _buildUnreadBadge(badgeLabel),
                ] else if (showCheck) ...[
                  const SizedBox(height: 6),
                  Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnreadBadge(String label) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
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
