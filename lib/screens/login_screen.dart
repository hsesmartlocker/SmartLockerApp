import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _showSnack(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!(email.endsWith('@edu.hse.ru') || email.endsWith('@hse.ru'))) {
      _showSnack('Введите почту с доменом hse.ru или edu.hse.ru');
      return;
    }
    if (password.isEmpty) {
      _showSnack('Введите пароль');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://hsesmartlocker.ru/auth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email, 'password': password},
      );

      final responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['access_token']);

        final userInfoResponse = await http.get(
          Uri.parse('https://hsesmartlocker.ru/users/me'),
          headers: {'Authorization': 'Bearer ${data['access_token']}'},
        );

        if (userInfoResponse.statusCode == 200) {
          final userInfo = jsonDecode(utf8.decode(userInfoResponse.bodyBytes));
          final userType = userInfo['user_type'];
          final route = userType == 3 ? '/admin' : '/booking';

          _showSnack('Успешный вход', color: Colors.green);

          Future.delayed(const Duration(milliseconds: 500), () {
            Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
          });
        } else {
          _showSnack('Ошибка при получении данных пользователя');
        }
      } else {
        String message = 'Ошибка авторизации';
        try {
          final error = jsonDecode(responseBody);
          message = error['detail'] ?? message;
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack('Ошибка подключения: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Вход'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.lock_outline, size: 60, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'SmartLocker HSE',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Введите почту и пароль',
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Почта',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Пароль',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text('Войти'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/forgot_password'),
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
              child: const Text('Забыли пароль?'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 10),
            const Text(
              'Возникли вопросы?',
              style: TextStyle(color: Colors.black54),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/main_support'),
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
              child: const Text('Написать в поддержку'),
            ),
          ],
        ),
      ),
    );
  }
}
