import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/constants.dart';
import '../screens/rider/riderAllDeliveriesScreen.dart';
import '../screens/rider/riderEarningsScreen.dart';

/// Bottom navigation indices for the rider shell.
abstract final class RiderNavIndex {
  static const int home = 0;
  static const int delivery = 1;
  static const int history = 2;
  static const int wallet = 3;
}

/// Requests which dashboard-hosted tab (Home or History) the rider dashboard
/// should show when it becomes visible again.
///
/// Delivery and Wallet live in sibling routes that replace one another, so the
/// pop-result chain back to the dashboard is not reliable. The dashboard
/// listens here instead. Notifications are sent even when the tab is unchanged
/// so the dashboard can always refresh on return.
class RiderDashboardTabController extends ChangeNotifier {
  int _index = RiderNavIndex.home;

  int get index => _index;

  void request(int index) {
    _index = index;
    notifyListeners();
  }

  void reset() => _index = RiderNavIndex.home;
}

final RiderDashboardTabController riderDashboardTab =
    RiderDashboardTabController();

PageRoute<T> riderFadeRoute<T>(Widget page) {
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
/// across rider routes. This lets it stay visually pinned during route
/// transitions instead of fading/rebuilding (which caused the icons to
/// "reload").
const String _riderBottomNavHeroTag = 'riderBottomNavHero';

Widget buildRiderBottomNavigationBar({
  required int currentIndex,
  required ValueChanged<int> onTap,
}) {
  return Hero(
    tag: _riderBottomNavHeroTag,
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
    child: _RiderBottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
    ),
  );
}

class _RiderBottomNavigationBar extends StatelessWidget {
  const _RiderBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        items: [
          _item('assets/icons/home.svg', 'Home'),
          _item('assets/icons/delivery.svg', 'Delivery'),
          _item('assets/icons/Pending.svg', 'History'),
          _item('assets/icons/wallet.svg', 'Wallet'),
        ],
      ),
    );
  }

  BottomNavigationBarItem _item(String asset, String label) {
    return BottomNavigationBarItem(
      icon: SvgPicture.asset(
        asset,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(Colors.grey[600]!, BlendMode.srcIn),
      ),
      activeIcon: SvgPicture.asset(
        asset,
        width: 20,
        height: 20,
        colorFilter: const ColorFilter.mode(
          AppColors.primaryGreen,
          BlendMode.srcIn,
        ),
      ),
      label: label,
    );
  }
}

/// Handles a bottom navigation tap from a route that sits on top of the rider
/// dashboard (Delivery or Wallet).
void handleRiderNavTap(
  BuildContext context, {
  required int targetIndex,
  required int currentIndex,
}) {
  if (targetIndex == currentIndex) return;

  if (targetIndex == RiderNavIndex.home ||
      targetIndex == RiderNavIndex.history) {
    riderDashboardTab.request(targetIndex);
    Navigator.pop(context, targetIndex);
    return;
  }

  // Sibling tabs replace each other so the dashboard never flashes into view
  // between two transitions.
  final Widget screen = targetIndex == RiderNavIndex.delivery
      ? const RiderAllDeliveriesScreen()
      : const RiderEarningsScreen();
  Navigator.pushReplacement(
    context,
    riderFadeRoute(screen),
    result: currentIndex,
  );
}
