import 'package:flutter/material.dart';

import '../../constants/constants.dart';
import '../../services/api_service.dart';
import '../../utils/customer_nav.dart';
import '../../widgets/empty_state_widget.dart';

/// Placeholder shell for customer tabs that do not have backend wiring yet.
class CustomerPlaceholderScreen extends StatefulWidget {
  final String title;
  final IconData icon;
  final int navIndex;

  const CustomerPlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.navIndex,
  });

  @override
  State<CustomerPlaceholderScreen> createState() =>
      _CustomerPlaceholderScreenState();
}

class _CustomerPlaceholderScreenState extends State<CustomerPlaceholderScreen> {
  bool _isGuest = true;

  @override
  void initState() {
    super.initState();
    _loadGuestState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[700]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              handleCustomerNavTap(
                context,
                targetIndex: CustomerNavIndex.home,
                currentIndex: widget.navIndex,
                isGuest: _isGuest,
              );
            }
          },
        ),
      ),
      body: EmptyStateWidget(
        icon: widget.icon,
        message: '${widget.title} coming soon',
        subtitle: 'This section is not available yet.',
      ),
      bottomNavigationBar: buildCustomerBottomNavigationBar(
        context: context,
        currentIndex: widget.navIndex,
        isGuest: _isGuest,
        onLoginSuccess: _loadGuestState,
      ),
    );
  }
}
