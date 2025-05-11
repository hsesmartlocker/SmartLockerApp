import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _loadingHSE = false;

  @override
  void initState() {
    super.initState();
    _checkTokenAndNavigate();
  }

  Future<void> _checkTokenAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      final response = await http.get(
        Uri.parse('https://hsesmartlocker.ru/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final userData = json.decode(utf8.decode(response.bodyBytes));
        final userType = userData['user_type'];

        Future.delayed(const Duration(milliseconds: 300), () {
          Navigator.pushNamedAndRemoveUntil(
            context,
            userType == 3 ? '/admin' : '/booking',
            (_) => false,
          );
        });
      }
    }
  }

  Future<void> _loginViaHSE() async {
    setState(() => _loadingHSE = true);

    try {
      const clientId = '19230-prj';
      const redirectUri = 'smartlocker://auth/callback';
      final authUrl =
          'https://profile.miem.hse.ru/auth/realms/MIEM/protocol/openid-connect/auth'
          '?client_id=$clientId'
          '&redirect_uri=$redirectUri'
          '&response_type=code';

      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: 'smartlocker',
      );

      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code == null) throw Exception('Не удалось получить код авторизации');

      final tokenRes = await http.post(
        Uri.parse('https://hsesmartlocker.ru/auth/exchange'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );

      if (tokenRes.statusCode != 200) {
        throw Exception('Ошибка получения токена');
      }

      final tokenData = json.decode(utf8.decode(tokenRes.bodyBytes));
      final token = tokenData['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      final userInfoRes = await http.get(
        Uri.parse('https://hsesmartlocker.ru/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (userInfoRes.statusCode == 200) {
        final user = jsonDecode(utf8.decode(userInfoRes.bodyBytes));
        final userType = user['user_type'];
        final route = userType == 3 ? '/admin' : '/booking';

        Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
      } else {
        _showSnack('Ошибка при получении пользователя');
      }
    } catch (e) {
      _showSnack('Ошибка входа: $e');
    }

    setState(() => _loadingHSE = false);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Icon(Icons.vpn_key_rounded, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'SmartLocker HSE',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Бронирование оборудования\nдля студентов и сотрудников',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _loadingHSE ? null : _loginViaHSE,
              icon: const Icon(Icons.lock_open_rounded),
              label:
                  _loadingHSE
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text('Войти через ЕЛК'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              icon: const Icon(Icons.login),
              label: const Text('Войти по паролю'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Зарегистрироваться'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black87,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
