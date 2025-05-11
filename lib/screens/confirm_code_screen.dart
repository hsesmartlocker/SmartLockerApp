import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ConfirmCodeScreen extends StatefulWidget {
  const ConfirmCodeScreen({Key? key}) : super(key: key);

  @override
  State<ConfirmCodeScreen> createState() => _ConfirmCodeScreenState();
}

class _ConfirmCodeScreenState extends State<ConfirmCodeScreen> {
  final _codeController = TextEditingController();
  late String email;
  late String password;
  late String Name;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    email = args['email'];
    password = args['password'];
    Name = args['name'];
    super.didChangeDependencies();
  }

  Future<void> confirmCode() async {
    setState(() => _isLoading = true);

    final response = await http.post(
      Uri.parse('https://hsesmartlocker.ru/auth/confirm-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': _codeController.text.trim(),
        'password': password,
        'name': Name,
      }),
    );

    setState(() => _isLoading = false);

    final contentType = response.headers['content-type'];

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final token = decoded['access_token'];
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Успешная регистрация'),
          backgroundColor: Colors.green,
        ),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.pushReplacementNamed(context, '/booking');
      });
    } else if (contentType != null &&
        contentType.contains('application/json')) {
      try {
        final decodedBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> responseBody = jsonDecode(decodedBody);
        final detail = responseBody['detail'];

        if (detail == 'Пользователь уже существует') {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Почта уже зарегистрирована'),
                  content: const Text('Вы можете войти в аккаунт.'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: const Text('Войти'),
                    ),
                  ],
                ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(detail.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при обработке ответа'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Произошла ошибка на сервере'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Подтверждение почты',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Проверьте вашу почту и введите код подтверждения',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Код',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : confirmCode,
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
