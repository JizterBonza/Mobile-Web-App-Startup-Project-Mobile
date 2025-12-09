import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/loginScreen.dart';
import 'screens/customerDashboardScreen.dart';
import 'screens/vendorDashboardScreen.dart';
import 'screens/riderDashboardScreen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'provider/provider.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
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
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AgrifyConnect App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginScreen(),
          '/customerDashboard': (context) => const CustomerDashboardScreen(),
          '/vendorDashboard': (context) => const VendorDashboardScreen(),
          '/riderDashboard': (context) => const RiderDashboardScreen(),
        },
      ),
    );
  }
}
