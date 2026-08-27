import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../constants/constants.dart';
import '../../provider/provider.dart';
import '../../utils/rider_nav.dart';
import '../../widgets/empty_state_widget.dart';

class RiderEarningsScreen extends StatefulWidget {
  const RiderEarningsScreen({super.key});

  @override
  State<RiderEarningsScreen> createState() => _RiderEarningsScreenState();
}

class _RiderEarningsScreenState extends State<RiderEarningsScreen> {
  List<Map<String, dynamic>> _allOrders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrders());
  }

  Future<void> _loadOrders({bool useCache = true}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final ordersProvider = context.read<OrdersProvider>();
    try {
      await ordersProvider.fetchRiderOrders(useCache: useCache);
      if (!mounted) return;
      setState(() {
        _allOrders = ordersProvider.orders;
        _error = ordersProvider.error;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() => _loadOrders(useCache: false);

  List<Map<String, dynamic>> get _completedDeliveries => _allOrders
      .where(
        (order) =>
            order['order_status']?.toString().trim().toLowerCase() ==
            'delivered',
      )
      .toList();

  double get _totalEarnings {
    var total = 0.0;
    for (final order in _completedDeliveries) {
      total += _shippingFee(order);
    }
    return total;
  }

  double _shippingFee(Map<String, dynamic> order) {
    return double.tryParse(order['shipping_fee']?.toString() ?? '') ?? 0;
  }

  String _formatCurrency(double amount, {bool showPositiveSign = false}) {
    final absoluteAmount = amount.abs();
    final fixed = absoluteAmount == absoluteAmount.truncateToDouble()
        ? absoluteAmount.toStringAsFixed(0)
        : absoluteAmount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts.first;
    final grouped = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        grouped.write(',');
      }
      grouped.write(digits[index]);
    }

    final decimals = parts.length == 2 ? '.${parts.last}' : '';
    final sign = amount < 0
        ? '-'
        : showPositiveSign
            ? '+'
            : '';
    return '$sign₱$grouped$decimals';
  }

  String _formatOrderDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.isEmpty ? 'Date unavailable' : raw;

    final date = parsed.toLocal();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final meridiem = date.hour < 12 ? 'am' : 'pm';
    return '${months[date.month - 1]} ${date.day}, ${date.year} '
        '• $hour:$minute$meridiem';
  }

  String _orderCode(Map<String, dynamic> order) {
    final value = order['order_code']?.toString().trim() ?? '';
    if (value.isEmpty) return 'ORDER';
    return value.startsWith('#') ? value.substring(1) : value;
  }

  void _onNavTap(int index) {
    handleRiderNavTap(
      context,
      targetIndex: index,
      currentIndex: RiderNavIndex.wallet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet',
                    key: ValueKey('wallet-title'),
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your delivery earnings.',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: ValueKey('wallet-loading'),
          color: AppColors.primaryGreenLight,
        ),
      );
    }

    if (_error != null) {
      return EmptyStateWidget(
        icon: Icons.cloud_off_outlined,
        message: 'Unable to load earnings',
        subtitle: _error,
        action: ElevatedButton(
          key: const ValueKey('wallet-retry'),
          onPressed: () => _loadOrders(useCache: false),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreenLight,
            foregroundColor: Colors.white,
          ),
          child: const Text('Retry'),
        ),
      );
    }

    final deliveries = _completedDeliveries;
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primaryGreenLight,
      child: ListView(
        key: const ValueKey('wallet-scroll-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        children: [
          _WalletBalanceCard(amount: _formatCurrency(_totalEarnings)),
          const SizedBox(height: 28),
          const _WalletTabs(),
          const SizedBox(height: 6),
          if (deliveries.isEmpty)
            const _WalletEmptyEarnings()
          else
            for (var index = 0; index < deliveries.length; index++) ...[
              _WalletEarningRow(
                key: ValueKey('wallet-earning-row-$index'),
                orderCode: _orderCode(deliveries[index]),
                date: _formatOrderDate(deliveries[index]['ordered_at']),
                amount: _formatCurrency(
                  _shippingFee(deliveries[index]),
                  showPositiveSign: true,
                ),
              ),
              if (index != deliveries.length - 1)
                const Divider(height: 1, color: Color(0xFFE2E2E2)),
            ],
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return buildRiderBottomNavigationBar(
      currentIndex: RiderNavIndex.wallet,
      onTap: _onNavTap,
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('wallet-balance-card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF21975C), Color(0xFF08713F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Balance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amount,
                      key: const ValueKey('wallet-available-balance'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 31,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SvgPicture.asset(
                  'assets/icons/wallet.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          const Divider(height: 1, color: Color(0x66FFFFFF)),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.show_chart, size: 14, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'Total Earned',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            amount,
            key: const ValueKey('wallet-total-earned'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              key: const ValueKey('wallet-withdraw-button'),
              onPressed: null,
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF16834E),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text(
                'Withdraw Earnings',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletTabs extends StatelessWidget {
  const _WalletTabs();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            key: const ValueKey('wallet-earnings-tab'),
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryGreenLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Earnings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 34,
            child: OutlinedButton(
              key: const ValueKey('wallet-withdrawals-tab'),
              onPressed: null,
              style: OutlinedButton.styleFrom(
                disabledForegroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreenLight),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'Withdrawals',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WalletEarningRow extends StatelessWidget {
  const _WalletEarningRow({
    super.key,
    required this.orderCode,
    required this.date,
    required this.amount,
  });

  final String orderCode;
  final String date;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFDDF4E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.south_west,
              color: AppColors.primaryGreenLight,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  orderCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 14,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 10,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: const TextStyle(
              color: AppColors.primaryGreenLight,
              fontSize: 14,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletEmptyEarnings extends StatelessWidget {
  const _WalletEmptyEarnings();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 230,
      child: EmptyStateWidget(
        icon: Icons.account_balance_wallet_outlined,
        message: 'No earnings yet',
        subtitle: 'Completed delivery earnings will appear here.',
      ),
    );
  }
}
