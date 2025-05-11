import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ConfirmResetCodeScreen extends StatefulWidget {
  const ConfirmResetCodeScreen({super.key});

  @override
  State<ConfirmResetCodeScreen> createState() => _ConfirmResetCodeScreenState();
}

class _ConfirmResetCodeScreenState extends State<ConfirmResetCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  late String email;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    email = args['email'];
    super.didChangeDependencies();
  }

  Future<void> _confirmCode() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://hsesmartlocker.ru/auth/reset-password/confirm-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': _codeController.text.trim()}),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Новый пароль отправлен вам на почту.'),
            backgroundColor: Colors.green,
          ),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/main');
        });
      } else {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final detail = decoded['detail'];

        String message;
        if (detail is String) {
          message = detail;
        } else if (detail is List) {
          message = detail.join(', ');
        } else {
          message = 'Произошла ошибка подтверждения';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
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
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F4FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text(
          'Подтверждение кода',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Введите код из письма',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              'Мы отправили его на $email',
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Код подтверждения',
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
                onPressed: _isLoading ? null : _confirmCode,
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
                        : const Text('Подтвердить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
