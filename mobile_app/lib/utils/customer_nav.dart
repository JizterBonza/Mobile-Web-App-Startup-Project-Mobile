import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../constants/constants.dart';
import '../provider/badge_provider.dart';
import '../screens/common/myOrderScreen.dart';
import '../screens/common/notificationScreen.dart';
import '../screens/customer/customerDashboardScreen.dart';
import '../screens/customer/customerPlaceholderScreen.dart';
import '../screens/customer/favoriteScreen.dart';
import '../widgets/login_dialog.dart';

/// Bottom navigation indices for the customer shell.
abstract final class CustomerNavIndex {
  static const int home = 0;
  static const int favorites = 1;
  static const int klasrum = 2;
  static const int orders = 3;
  static const int notifs = 4;
}

Widget _customerNavSvgIcon({
  required String asset,
  required Color color,
}) {
  return SizedBox(
    width: 24,
    height: 24,
    child: SvgPicture.asset(
      asset,
      height: 24,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    ),
  );
}

Widget _customerNavIconWithBadge({
  required String asset,
  required Color color,
  String? badgeCount,
}) {
  final icon = _customerNavSvgIcon(asset: asset, color: color);
  if (badgeCount == null) return icon;

  return SizedBox(
    width: 32,
    height: 28,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Center(child: icon),
        Positioned(
          right: 0,
          top: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentAmber,
              borderRadius: BorderRadius.circular(4),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              badgeCount,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _customerNotifsNavIcon({
  required Color color,
  required bool isGuest,
}) {
  return Consumer<BadgeProvider>(
    builder: (context, badges, _) {
      final count = isGuest
          ? null
          : BadgeProvider.formatBadgeCount(badges.unreadNotifications);
      return _customerNavIconWithBadge(
        asset: 'assets/icons/notif.svg',
        color: color,
        badgeCount: count,
      );
    },
  );
}

PageRoute<T> customerFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 150),
    reverseTransitionDuration: const Duration(milliseconds: 150),
  );
}

/// Shared Hero tag so the bottom navigation bar is treated as the same element
/// across customer routes. This lets it stay visually pinned during route
/// transitions instead of fading/rebuilding (which caused the icons to "reload").
const String _customerBottomNavHeroTag = 'customerBottomNavHero';

Widget buildCustomerBottomNavigationBar({
  required BuildContext context,
  required int currentIndex,
  required bool isGuest,
  VoidCallback? onLoginSuccess,
}) {
  return Hero(
    tag: _customerBottomNavHeroTag,
    // Keep the originating (already-rendered) nav bar on screen for the whole
    // flight so the SVG icons never blank out while the new screen fades in.
    flightShuttleBuilder: (
      flightContext,
      animation,
      flightDirection,
      fromHeroContext,
      toHeroContext,
    ) {
      return fromHeroContext.widget;
    },
    child: _buildCustomerBottomNavigationBarContent(
      context: context,
      currentIndex: currentIndex,
      isGuest: isGuest,
      onLoginSuccess: onLoginSuccess,
    ),
  );
}

Widget _buildCustomerBottomNavigationBarContent({
  required BuildContext context,
  required int currentIndex,
  required bool isGuest,
  VoidCallback? onLoginSuccess,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.grey[300]!)),
    ),
    child: BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => handleCustomerNavTap(
        context,
        targetIndex: index,
        currentIndex: currentIndex,
        isGuest: isGuest,
        onLoginSuccess: onLoginSuccess,
      ),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: Colors.grey[600],
      backgroundColor: Colors.white,
      selectedFontSize: 11,
      unselectedFontSize: 10,
      items: [
        BottomNavigationBarItem(
          icon: _customerNavSvgIcon(
            asset: 'assets/icons/home.svg',
            color: Colors.grey[600]!,
          ),
          activeIcon: _customerNavSvgIcon(
            asset: 'assets/icons/home.svg',
            color: AppColors.primaryGreenDark,
          ),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: _customerNavSvgIcon(
            asset: 'assets/icons/favorite.svg',
            color: Colors.grey[600]!,
          ),
          activeIcon: _customerNavSvgIcon(
            asset: 'assets/icons/favorite.svg',
            color: AppColors.primaryGreenDark,
          ),
          label: 'Favorite',
        ),
        BottomNavigationBarItem(
          icon: _customerNavSvgIcon(
            asset: 'assets/icons/klasrum.svg',
            color: Colors.grey[600]!,
          ),
          activeIcon: _customerNavSvgIcon(
            asset: 'assets/icons/klasrum.svg',
            color: AppColors.primaryGreenDark,
          ),
          label: 'Klasrum',
        ),
        BottomNavigationBarItem(
          icon: _customerNavSvgIcon(
            asset: 'assets/icons/orders.svg',
            color: Colors.grey[600]!,
          ),
          activeIcon: _customerNavSvgIcon(
            asset: 'assets/icons/orders.svg',
            color: AppColors.primaryGreenDark,
          ),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: _customerNotifsNavIcon(
            color: Colors.grey[600]!,
            isGuest: isGuest,
          ),
          activeIcon: _customerNotifsNavIcon(
            color: AppColors.primaryGreenDark,
            isGuest: isGuest,
          ),
          label: 'Notifs',
        ),
      ],
    ),
  );
}

void handleCustomerNavTap(
  BuildContext context, {
  required int targetIndex,
  required int currentIndex,
  required bool isGuest,
  VoidCallback? onLoginSuccess,
}) {
  if (targetIndex == currentIndex) return;

  if (targetIndex != CustomerNavIndex.home && isGuest) {
    showLoginDialog(context, onLoginSuccess: onLoginSuccess);
    return;
  }

  if (targetIndex == CustomerNavIndex.home) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        customerFadeRoute(const CustomerDashboardScreen()),
      );
    }
    return;
  }

  final Widget screen = switch (targetIndex) {
    CustomerNavIndex.favorites => const FavoriteScreen(),
    CustomerNavIndex.klasrum => const CustomerPlaceholderScreen(
        title: 'Klasrum',
        icon: Icons.menu_book_outlined,
        navIndex: CustomerNavIndex.klasrum,
      ),
    CustomerNavIndex.orders => const MyOrderScreen(showCustomerBottomNav: true),
    CustomerNavIndex.notifs =>
      const NotificationScreen(showCustomerBottomNav: true),
    _ => const CustomerDashboardScreen(),
  };

  if (currentIndex == CustomerNavIndex.home) {
    Navigator.push(context, customerFadeRoute(screen));
  } else {
    Navigator.pushReplacement(context, customerFadeRoute(screen));
  }
}
