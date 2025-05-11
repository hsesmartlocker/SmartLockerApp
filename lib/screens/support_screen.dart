import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendSupportRequest() async {
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, введите сообщение'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка авторизации. Войдите заново.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://hsesmartlocker.ru/support'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': message}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Обращение отправлено. Мы ответим в течение суток'),
            backgroundColor: Colors.green,
          ),
        );
        final userRes = await http.get(
          Uri.parse('https://hsesmartlocker.ru/users/me'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (userRes.statusCode == 200) {
          final userData = json.decode(utf8.decode(userRes.bodyBytes));
          final userType = userData['user_type'];

          final route = userType == 3 ? '/admin' : '/booking';

          Future.delayed(const Duration(seconds: 1), () {
            Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
          });
        }
      } else {
        final decoded = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> body = json.decode(decoded);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['detail'] ?? 'Ошибка сервера'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка сети. Попробуйте позже.'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: const Text('Поддержка', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            const Text(
              'Опишите вашу проблему или вопрос.\nМы ответим в течение 24 часов.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Введите ваше сообщение...',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendSupportRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'Отправить',
                          style: TextStyle(fontSize: 16),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
