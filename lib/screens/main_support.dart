import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MainSupportScreen extends StatefulWidget {
  const MainSupportScreen({super.key});

  @override
  State<MainSupportScreen> createState() => _MainSupportScreenState();
}

class _MainSupportScreenState extends State<MainSupportScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitSupport() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final message = _messageController.text.trim();

    if (name.isEmpty || email.isEmpty || message.isEmpty) {
      _showSnackBar('Пожалуйста, заполните все поля');
      return;
    }

    if (!(email.endsWith('@hse.ru') || email.endsWith('@edu.hse.ru'))) {
      _showSnackBar('Введите почту с доменом hse.ru или edu.hse.ru');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://hsesmartlocker.ru/support/anonymous'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'message': message}),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        _nameController.clear();
        _emailController.clear();
        _messageController.clear();
        _showSnackBar(
          'Обращение отправлено. Мы ответим в течение 24 часов',
          success: true,
        );
      } else {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final detail = decoded['detail'] ?? 'Ошибка при отправке';
        _showSnackBar(detail.toString());
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Ошибка сети. Попробуйте позже.');
    }
  }

  void _showSnackBar(String text, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Обращение в поддержку'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Text(
              'Если у вас возникли вопросы или проблемы — напишите нам. Мы постараемся ответить как можно скорее.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Ваше имя',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Ваша почта (hse.ru / edu.hse.ru)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Сообщение',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitSupport,
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
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Отправить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
