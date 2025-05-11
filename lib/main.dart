import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/support_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/booking_details_screen.dart';
import 'screens/booking_history_screen.dart';
import 'screens/new_booking_screen.dart';
import 'screens/confirm_code_screen.dart';
import 'screens/main_support.dart';
import 'screens/splash_screen.dart';
import 'screens/about_locker_screen.dart';
import 'screens/confirm_reset_code_screen.dart';
import 'screens/items_screen.dart';
import 'screens/new_item_screen.dart';
import 'screens/no_connection_screen.dart';

void main() {
  runApp(const CampusApp());
}

class CampusApp extends StatelessWidget {
  const CampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  Widget? _startScreen;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final hasInternet = await _checkInternet();

    if (!hasInternet) {
      setState(() => _startScreen = const NoConnectionScreen());
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null && token.isNotEmpty) {
      final res = await http.get(
        Uri.parse('https://hsesmartlocker.ru/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final userBody = res.body;
        final match = RegExp(r'"user_type":\s?(\d)').firstMatch(userBody);
        final type = int.tryParse(match?.group(1) ?? '');
        setState(() {
          _startScreen =
              type == 3 ? const AdminScreen() : const BookingScreen();
        });
        return;
      }

      setState(() => _startScreen = const BookingScreen());
    } else {
      setState(() => _startScreen = const MainScreen());
    }
  }

  Future<bool> _checkInternet() async {
    try {
      final res = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_startScreen == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MaterialApp(
      title: 'Campus App',
      debugShowCheckedModeBanner: false,
      home: _startScreen,
      routes: {
        '/main': (context) => const MainScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const SplashScreen(),
        '/register': (context) => const RegisterScreen(),
        '/confirm_code': (context) => const ConfirmCodeScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/support': (context) => const SupportScreen(),
        '/booking': (context) => const BookingScreen(),
        '/admin': (context) => const AdminScreen(),
        '/change_password': (context) => const ChangePasswordScreen(),
        '/booking_details': (context) => const BookingDetailsScreen(),
        '/booking_history': (context) => const BookingHistoryScreen(),
        '/new_booking': (context) => const NewBookingScreen(),
        '/main_support': (context) => const MainSupportScreen(),
        '/about_locker': (context) => const AboutLockerScreen(),
        '/reset_confirm': (context) => const ConfirmResetCodeScreen(),
        '/items': (context) => const ItemsScreen(),
        '/new_item': (context) => const NewItemScreen(),
        '/no_connection': (context) => const NoConnectionScreen(),
      },
    );
  }
}
