// Match the existing customer screen filenames.
// ignore_for_file: file_names

import 'package:flutter/material.dart';

import '../../constants/constants.dart';
import '../../services/api_service.dart';
import '../../services/farms_service.dart';
import '../../utils/customer_nav.dart';
import 'farmDetailsScreen.dart';

class PartnerFarmsScreen extends StatefulWidget {
  const PartnerFarmsScreen({super.key, this.farmsService});

  final FarmsService? farmsService;

  @override
  State<PartnerFarmsScreen> createState() => _PartnerFarmsScreenState();
}

class _PartnerFarmsScreenState extends State<PartnerFarmsScreen> {
  late final FarmsService _farmsService;
  List<Map<String, dynamic>> _farms = [];
  bool _isLoading = true;
  bool _isFetching = false;
  bool _isGuest = true;
  bool _hasLoaded = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _farmsService = widget.farmsService ?? FarmsService();
    _loadGuestState();
    _loadFarms();
  }

  Future<void> _loadGuestState() async {
    try {
      final token = await ApiService.getToken();
      if (!mounted) return;
      setState(() => _isGuest = token == null || token.isEmpty);
    } catch (_) {
      if (mounted) setState(() => _isGuest = true);
    }
  }

  Future<void> _loadFarms({bool refresh = false}) async {
    if (_isFetching) return;
    _isFetching = true;
    if (!refresh) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    try {
      final farms = await _farmsService.fetchFarms();
      if (!mounted) return;
      setState(() {
        _farms = farms;
        _hasLoaded = true;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (refresh && _hasLoaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to refresh partner farms')),
        );
      } else {
        setState(() => _hasError = true);
      }
    } finally {
      _isFetching = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Partner Gamefarms'),
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadFarms(refresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_hasError || _farms.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_hasError
                          ? 'Failed to load partner farms'
                          : 'No partner farms available'),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadFarms,
                        child: Text(_hasError ? 'Retry' : 'Refresh'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildFarmCard(_farms[index]),
                    ),
                    childCount: _farms.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: buildCustomerBottomNavigationBar(
        context: context,
        currentIndex: CustomerNavIndex.farms,
        isGuest: _isGuest,
        onLoginSuccess: () {
          _loadGuestState();
          _loadFarms(refresh: true);
        },
      ),
    );
  }

  String _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.toLowerCase() == 'null' ? '' : text;
  }

  Widget _buildFarmCard(Map<String, dynamic> farm) {
    final farmId = farm['id'];
    final name = _text(farm['name']);
    final location = [_text(farm['city']), _text(farm['province'])]
        .where((part) => part.isNotEmpty)
        .join(', ');
    final address = location.isNotEmpty ? location : _text(farm['address']);
    final imageUrl = ['cover_url', 'banner_url', 'logo_url']
        .map((key) => _text(farm[key]))
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    Widget fallback() => Image.asset(
          'assets/images/farmer_image.png',
          fit: BoxFit.cover,
        );

    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('partner-farm-$farmId'),
          onTap: farmId == null || _text(farmId).isEmpty
              ? null
              : () => Navigator.push(
                    context,
                    customerFadeRoute(FarmDetailsScreen(
                      farmId: farmId,
                      farmName: name.isEmpty ? null : name,
                      farmsService: _farmsService,
                    )),
                  ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl.isEmpty
                  ? fallback()
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => fallback(),
                    ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Unnamed Farm' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
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
}
