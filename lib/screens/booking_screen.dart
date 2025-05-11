// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<dynamic> bookings = [];
  String name = '';
  String userType = '';

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('https://hsesmartlocker.ru/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (!mounted) return;
      setState(() {
        name = data['name'] ?? '';
        final email = data['email'] ?? '';
        userType =
            email.endsWith('@edu.hse.ru')
                ? 'Студент'
                : email.endsWith('@hse.ru')
                ? 'Сотрудник'
                : 'Гость';
      });
    }
  }

  Future<void> _loadBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      return;
    }

    final response = await http.get(
      Uri.parse('https://hsesmartlocker.ru/requests/my'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      final now = DateTime.now();

      final filtered =
          data.where((booking) {
            final status = (booking['status'] ?? '').toLowerCase();
            return status != 'возвращено' && status != 'отклонена';
          }).toList();

      filtered.sort((a, b) {
        final aDate =
            DateTime.tryParse(a['planned_return_date'] ?? '') ??
            now.add(const Duration(days: 365));
        final bDate =
            DateTime.tryParse(b['planned_return_date'] ?? '') ??
            now.add(const Duration(days: 365));
        final aIsUrgent = aDate.difference(now).inHours < 24;
        final bIsUrgent = bDate.difference(now).inHours < 24;
        if (aIsUrgent && !bIsUrgent) return -1;
        if (!aIsUrgent && bIsUrgent) return 1;
        return aDate.compareTo(bDate);
      });

      if (!mounted) return;
      setState(() => bookings = filtered);
    }
  }

  String _getStatusText(String status, String? returnDateStr) {
    final returnDate = DateTime.tryParse(returnDateStr ?? '');
    if (["Ожидает возврата", "Выдано", "Просрочено"].contains(status) &&
        returnDate != null) {
      final adjusted = returnDate.add(const Duration(hours: 3));
      return 'Вернуть до ${DateFormat('dd.MM.yyyy HH:mm').format(adjusted)}';
    }
    return status;
  }

  Color _getStatusDotColor(String status) {
    switch (status) {
      case 'Создана':
      case 'На рассмотрении':
      case 'Ожидает получения':
        return Colors.orange;
      case 'Выдано':
      case 'Ожидает возврата':
        return Colors.green;
      case 'Отклонена':
      case 'Просрочено':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Лимит бронирований',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'У вас уже максимальное количество бронирований. Если нужно больше — обратитесь в поддержку.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/support'),
                child: const Text(
                  'В поддержку',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Закрыть',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
    );
  }

  void _handleNewBooking() {
    if (bookings.length >= 3) {
      _showLimitDialog();
    } else {
      Navigator.pushNamed(context, '/new_booking');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F4FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true, // добавь эту строку
        title: const Text('SmartLocker', style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadBookings,
            tooltip: 'Обновить',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userType,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(name, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child:
                bookings.isEmpty
                    ? const Center(child: Text('Нет активных заявок'))
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        final itemName = booking['item_name'] ?? 'Оборудование';
                        final status = booking['status'] ?? 'неизвестно';
                        final plannedDate = booking['planned_return_date'];
                        final now = DateTime.now();
                        final returnDate = DateTime.tryParse(plannedDate ?? '');
                        final isUrgent =
                            returnDate != null &&
                            returnDate.difference(now).inHours < 24;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side:
                                isUrgent
                                    ? const BorderSide(
                                      color: Colors.red,
                                      width: 1.5,
                                    )
                                    : BorderSide.none,
                          ),
                          color: Colors.white,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: _getStatusDotColor(status),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    itemName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _getStatusText(status, plannedDate),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final result = await Navigator.pushNamed(
                                context,
                                '/booking_details',
                                arguments: booking,
                              );
                              if (result == true) _loadBookings();
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleNewBooking,
        backgroundColor: Colors.blue,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/about_locker'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.location_on_outlined),
                    SizedBox(height: 4),
                    Text('Где SmartLocker?'),
                  ],
                ),
              ),
              const SizedBox(width: 48),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/booking_history'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.import_contacts_outlined),
                    SizedBox(height: 4),
                    Text('Архив заявок'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
