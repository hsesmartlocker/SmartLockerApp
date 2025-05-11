import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty ||
        !(email.endsWith('@edu.hse.ru') || email.endsWith('@hse.ru'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите почту с доменом @edu.hse.ru или @hse.ru'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(
        'https://hsesmartlocker.ru/auth/reset-password/send-code?email=$email',
      );

      final response = await http.post(uri);

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        Navigator.pushNamed(
          context,
          '/reset_confirm',
          arguments: {'email': email},
        );
      } else {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final detail = decoded['detail'] ?? 'Ошибка при отправке кода';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка сети. Попробуйте позже.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F4FC),
      appBar: AppBar(
        title: const Text(
          'Восстановление пароля',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Введите вашу корпоративную почту',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text(
              'На неё придёт код для восстановления доступа.',
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Почта @edu.hse.ru / @hse.ru',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitEmail,
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
                        : const Text('Получить код'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
