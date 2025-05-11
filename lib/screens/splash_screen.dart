import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _goTo('/');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://hsesmartlocker.ru/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final userType = data['user_type'];

        if (userType == 3) {
          _goTo('/admin');
        } else {
          _goTo('/booking');
        }
      } else {
        _goTo('/');
      }
    } catch (e) {
      _goTo('/');
    }
  }

  void _goTo(String route) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF6F8FA),
      body: Center(child: CircularProgressIndicator(color: Colors.blue)),
    );
  }
}
