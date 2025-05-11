import 'package:flutter/material.dart';

class AboutLockerScreen extends StatelessWidget {
  const AboutLockerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F4FC),
      appBar: AppBar(
        title: const Text('Где SmartLocker?'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  'Фото SmartLocker появится здесь',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '📍 МИЭМ НИУ ВШЭ\nМосква, ул. Таллинская, д. 34',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'SmartLocker находится на цокольном (-1) этаже\nсправа от гардероба. Перед лифтами\nв Административный корпус.',
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Окей, понятно!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
