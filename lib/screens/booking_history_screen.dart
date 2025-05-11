import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  List<dynamic> history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      return;
    }

    final response = await http.get(
      Uri.parse('https://hsesmartlocker.ru/requests/history'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final decoded = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(decoded);
      setState(() {
        history = data;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка при загрузке истории'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'отменена':
        return Colors.red;
      case 'возвращено':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'отменена':
        return Icons.close_rounded;
      case 'возвращено':
        return Icons.check_circle_outline;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'История бронирований',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body:
          history.isEmpty
              ? const Center(child: Text('История пуста'))
              : ListView.builder(
                itemCount: history.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final booking = history[index];
                  final itemName = booking['item_name'] ?? 'Оборудование';
                  final status = booking['status'] ?? 'неизвестно';
                  final createdStr = booking['created'];
                  final created =
                      DateTime.tryParse(createdStr ?? '') ?? DateTime.now();
                  final formattedCreated = DateFormat(
                    'dd.MM.yyyy, HH:mm',
                  ).format(created);
                  final color = _getStatusColor(status);
                  final icon = _getStatusIcon(status);

                  return Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.1),
                        child: Icon(icon, color: color),
                      ),
                      title: Text(
                        itemName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Создана: $formattedCreated',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      enabled: false,
                    ),
                  );
                },
              ),
    );
  }
}
