import 'package:flutter/material.dart';

import '../../../constants/constants.dart';
import '../../../services/shops_service.dart';
import '../shopScreen.dart';

class BreederSearchInterface extends StatefulWidget {
  const BreederSearchInterface({super.key});

  @override
  State<BreederSearchInterface> createState() => _BreederSearchInterfaceState();
}

/// Inline breeder/gamefarm matches shown beneath the newsfeed search field.
class BreederPageSearchResults extends StatefulWidget {
  const BreederPageSearchResults({super.key, required this.query});

  final String query;

  @override
  State<BreederPageSearchResults> createState() =>
      _BreederPageSearchResultsState();
}

class _BreederPageSearchResultsState extends State<BreederPageSearchResults> {
  final _service = ShopsService();
  final Set<String> _following = {};
  List<Map<String, dynamic>> _shops = [];
  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.query.trim().isNotEmpty) _loadShops();
  }

  @override
  void didUpdateWidget(covariant BreederPageSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query.trim().isEmpty &&
        widget.query.trim().isNotEmpty &&
        !_loaded) {
      _loadShops();
    }
  }

  Future<void> _loadShops() async {
    setState(() => _loading = true);
    try {
      final shops = await _service.fetchShops();
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _loading = false;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loaded = true;
      });
    }
  }

  List<Map<String, dynamic>> get _matches {
    final query = widget.query.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _shops.where((shop) {
      final content = [
        shop['shop_name'],
        shop['shop_description'],
        shop['shop_address'],
        shop['breeder_name'],
      ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
      return content.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isEmpty) return const SizedBox.shrink();
    final matches = _matches;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 7),
            child: Text('Breeder Pages',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (matches.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Text('No matching breeder pages.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF777A82))),
            )
          else
            for (final shop in matches.take(5)) ...[
              _buildResult(shop),
              const SizedBox(height: 7),
            ],
        ],
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> shop) {
    final id = shop['id']?.toString() ?? '';
    final name = shop['shop_name']?.toString().trim();
    final logo = shop['shop_logo']?.toString();
    final isFollowing = _following.contains(id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              width: 42,
              height: 42,
              child: logo != null && logo.isNotEmpty
                  ? Image.network(logo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarPlaceholder())
                  : _avatarPlaceholder(),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: InkWell(
              onTap: () {
                if (shop['id'] == null) return;
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ShopScreen(
                    shopId: shop['id'],
                    shopName: name,
                  ),
                ));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name?.isNotEmpty == true ? name! : 'Gamefarm',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(
                    'Gamefarm  |  ${shop['followers_count'] ?? shop['followers'] ?? 0} followers',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF858891)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 30,
            child: isFollowing
                ? OutlinedButton(
                    onPressed: () => setState(() => _following.remove(id)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandPrimary,
                      side: const BorderSide(color: Color(0xFFB7C4EA)),
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: const Text('Following'),
                  )
                : FilledButton(
                    onPressed: id.isEmpty
                        ? null
                        : () => setState(() => _following.add(id)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: const Text('Follow'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() => const ColoredBox(
        color: Color(0xFFE2E4E8),
        child: Icon(Icons.storefront, color: Colors.white, size: 22),
      );
}

class _BreederSearchInterfaceState extends State<BreederSearchInterface> {
  final _searchController = TextEditingController();
  final _shopsService = ShopsService();
  final Set<String> _following = {};
  List<Map<String, dynamic>> _gamefarms = [];
  bool _loading = true;
  bool _showAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGamefarms();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGamefarms() async {
    try {
      final shops = await _shopsService.fetchShops();
      if (!mounted) return;
      setState(() {
        _gamefarms = shops;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load gamefarms. Check your connection and retry.';
      });
    }
  }

  List<Map<String, dynamic>> get _filteredGamefarms {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _gamefarms.where((shop) {
      final searchableText = [
        shop['shop_name'],
        shop['shop_description'],
        shop['shop_address'],
        shop['breeder_name'],
      ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
      return query.isEmpty || searchableText.contains(query);
    }).toList();
    return _showAll || query.isNotEmpty ? filtered : filtered.take(5).toList();
  }

  void _toggleFollow(Map<String, dynamic> shop) {
    final id = shop['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      if (!_following.add(id)) _following.remove(id);
    });
  }

  void _openGamefarm(Map<String, dynamic> shop) {
    final id = shop['id'];
    if (id == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ShopScreen(shopId: id, shopName: shop['shop_name']?.toString()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final gamefarms = _filteredGamefarms;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 14),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const SizedBox(
                        width: 38,
                        height: 38,
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 17, color: Color(0xFF9A9CA2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Gamefarm Name',
                          hintStyle: const TextStyle(
                              fontSize: 14, color: Color(0xFF9A9CA2)),
                          prefixIcon: const Icon(Icons.search,
                              size: 18, color: Color(0xFF9A9CA2)),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: _searchController.clear,
                                  icon: const Icon(Icons.cancel,
                                      size: 17, color: Color(0xFFBFC1C5)),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('Gamefarms',
                        style: TextStyle(
                            color: Color(0xFF343741),
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (_loading)
                    const Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(child: CircularProgressIndicator()))
                  else if (_error != null)
                    _message(_error!,
                        action: TextButton(
                          onPressed: () {
                            setState(() => _loading = true);
                            _loadGamefarms();
                          },
                          child: const Text('Retry'),
                        ))
                  else if (gamefarms.isEmpty)
                    _message(_searchController.text.trim().isEmpty
                        ? 'No gamefarms available yet.'
                        : 'No gamefarms match your search.')
                  else ...[
                    for (final shop in gamefarms) ...[
                      _gamefarmCard(shop),
                      const SizedBox(height: 8),
                    ],
                    if (!_showAll &&
                        _searchController.text.trim().isEmpty &&
                        _gamefarms.length > gamefarms.length)
                      Center(
                          child: TextButton(
                        onPressed: () => setState(() => _showAll = true),
                        child: const Text('See All',
                            style: TextStyle(
                                color: AppColors.brandPrimary, fontSize: 14)),
                      )),
                  ],
                  const Divider(height: 18, color: Color(0xFFE0E0E0)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(String message, {Widget? action}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777A82), fontSize: 14)),
          if (action != null) action,
        ]),
      );

  Widget _gamefarmCard(Map<String, dynamic> shop) {
    final id = shop['id']?.toString() ?? '';
    final rawName = shop['shop_name']?.toString().trim();
    final name = rawName == null || rawName.isEmpty ? 'Gamefarm' : rawName;
    final logo = shop['shop_logo']?.toString();
    final followers = shop['followers_count'] ?? shop['followers'] ?? 0;
    final isFollowing = _following.contains(id);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openGamefarm(shop),
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: logo != null && logo.isNotEmpty
                      ? Image.network(logo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderAvatar())
                      : _placeholderAvatar(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF777B84),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Text('Gamefarm  |  $followers followers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF9A9DA4), fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 28,
                child: isFollowing
                    ? OutlinedButton(
                        onPressed: () => _toggleFollow(shop),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brandPrimary,
                            side: const BorderSide(color: Color(0xFFB7C4EA)),
                            padding: const EdgeInsets.symmetric(horizontal: 9),
                            minimumSize: const Size(0, 28),
                            textStyle: const TextStyle(fontSize: 11)),
                        child: const Text('Following'),
                      )
                    : FilledButton(
                        onPressed: () => _toggleFollow(shop),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 28),
                            textStyle: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                        child: const Text('Follow'),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _placeholderAvatar() => const ColoredBox(
        color: Color(0xFFC8C8C8),
        child: Icon(Icons.storefront, color: Colors.white, size: 20),
      );
}
