import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'constants/constants.dart';
import 'screens/common/loginScreen.dart';
import 'screens/customer/customerDashboardScreen.dart';
import 'screens/vendor/vendorDashboardScreen.dart';
import 'screens/rider/riderDashboardScreen.dart';
import 'screens/rider/riderPickupMap.dart';
import 'screens/rider/riderDeliveryMap.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'provider/provider.dart';
import 'models/order_status.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Hive
  await Hive.initFlutter();

  // Register Hive adapters
  // Note: Run 'flutter pub run build_runner build' to generate the adapter
  // Hive.registerAdapter(DeliveryPhotoModelAdapter());
  // Hive.registerAdapter(OrderStatusAdapter());

  // Open Hive boxes
  // Open delivery photos box (using Map for now until adapter is generated)
  await Hive.openBox('delivery_photos');

  // Open order statuses box
  // Note: Uncomment the adapter registration above after running build_runner
  await Hive.openBox<OrderStatus>('order_statuses');

  // Warm the SVG cache for the customer bottom-nav icons so they paint
  // instantly on first render and never blank out during navigation.
  await _precacheCustomerNavIcons();

  runApp(const MyApp());
}

Future<void> _precacheCustomerNavIcons() async {
  const navIcons = [
    'assets/icons/home.svg',
    'assets/icons/favorite.svg',
    'assets/icons/klasrum.svg',
    'assets/icons/orders.svg',
    'assets/icons/notif.svg',
  ];
  for (final asset in navIcons) {
    try {
      final loader = SvgAssetLoader(asset);
      await svg.cache.putIfAbsent(
        loader.cacheKey(null),
        () => loader.loadBytes(null),
      );
    } catch (_) {
      // Ignore precache failures; icons will still load lazily on demand.
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AddressProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => ItemsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => OrderStatusProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => PodProvider()),
        ChangeNotifierProvider(create: (_) => ShopsProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AgrifyConnect App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryGreen,
            primary: AppColors.primaryGreen,
            secondary: AppColors.accentAmber,
            surface: Colors.white,
            error: AppColors.error,
          ),
          scaffoldBackgroundColor: AppColors.surfaceLight,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor: AppColors.primaryGreen,
            unselectedItemColor: AppColors.textSecondary,
            backgroundColor: Colors.white,
          ),
        ),
        initialRoute: '/customerDashboard',
        routes: {
          '/': (context) => const LoginScreen(),
          '/customerDashboard': (context) => const CustomerDashboardScreen(),
          '/vendorDashboard': (context) => const VendorDashboardScreen(),
          '/riderDashboard': (context) => const RiderDashboardScreen(),
          '/riderPickupMap': (context) => const RiderPickupMapScreen(),
          '/riderDeliveryMap': (context) => const RiderDeliveryMapScreen(),
        },
      ),
    );
  }
}
