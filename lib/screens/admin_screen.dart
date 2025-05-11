import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<dynamic> requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final requestsResponse = await http.get(
        Uri.parse('https://hsesmartlocker.ru/requests/all'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (requestsResponse.statusCode != 200) {
        throw Exception('Ошибка при получении заявок');
      }

      final List<dynamic> rawRequests = json.decode(
        utf8.decode(requestsResponse.bodyBytes),
      );

      final itemsResponse = await http.get(
        Uri.parse('https://hsesmartlocker.ru/items/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final List<dynamic> itemsList = json.decode(
        utf8.decode(itemsResponse.bodyBytes),
      );

      final Map<int, Map<String, dynamic>> itemInfoById = {
        for (var item in itemsList) item['id']: item,
      };

      final List<dynamic> enriched = [];

      for (var r in rawRequests) {
        if ([2, 6, 8].contains(r['status'])) continue;

        final int userId = r['user'];
        final userResponse = await http.get(
          Uri.parse('https://hsesmartlocker.ru/users/$userId'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (userResponse.statusCode == 200) {
          final userData = json.decode(utf8.decode(userResponse.bodyBytes));
          r['user_email'] = userData['email'];
          r['user_type'] = userData['user_type'];
          r['user_name'] = userData['name'];
        } else {
          r['user_email'] = 'Неизвестно';
          r['user_type'] = 0;
          r['user_name'] = null;
        }

        final itemId = int.tryParse(r['item_id'].toString());
        r['item_name'] = itemInfoById[itemId]?['name'] ?? 'Оборудование';
        r['item_access'] = itemInfoById[itemId]?['access_level'] ?? 1;

        enriched.add(r);
      }

      if (!mounted) return;
      setState(() {
        requests = enriched;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки данных: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  void _showRejectionDialog(int requestId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Причина отклонения'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Укажите причину отказа...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateStatus(requestId, 2, reasonController.text.trim());
                },
                style: TextButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Отклонить',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _updateStatus(
    int requestId,
    int status, [
    String? reason,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final body = {
      'request_id': requestId,
      'status': status,
      if (reason != null) 'reason': reason,
    };

    final response = await http.post(
      Uri.parse('https://hsesmartlocker.ru/requests/update-status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      _loadRequests();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось обновить статус'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _changeReturnDateDialog(int requestId) async {
    DateTime now = DateTime.now();
    DateTime firstDate = now.add(const Duration(days: 1));
    DateTime lastDate = now.add(const Duration(days: 60));

    final picked = await showDatePicker(
      context: context,
      initialDate: firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Выберите новую дату возврата',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            dialogBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final res = await http.post(
        Uri.parse('https://hsesmartlocker.ru/requests/change_return_date'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'request_id': requestId,
          'new_date': picked.toIso8601String(),
        }),
      );

      if (res.statusCode == 200) {
        _loadRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при изменении даты возврата'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getUserType(int type) {
    return switch (type) {
      1 => 'Студент',
      2 => 'Сотрудник',
      _ => 'Неизвестно',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F4FC),
      appBar: AppBar(
        title: const Text(
          'Админ-панель',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRequests),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              )
              : requests.isEmpty
              ? const Center(child: Text('Нет заявок на рассмотрение'))
              : ListView.builder(
                itemCount: requests.length,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                itemBuilder: (context, index) {
                  final r = requests[index];
                  final userType = _getUserType(r['user_type'] ?? 0);
                  final email = r['user_email'] ?? '—';
                  final name = r['user_name'] ?? '';
                  final itemName = r['item_name'] ?? 'Оборудование';
                  final reason = r['comment'] ?? '—';
                  final requestId = r['id'];
                  final plannedDate = r['planned_return_date'];
                  final status = r['status'];
                  final accessLevel = r['item_access'] ?? 1;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('$userType — $email'),
                          if (name.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                name,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (status == 3)
                            Text(
                              accessLevel == 1
                                  ? 'Автоматическое бронирование'
                                  : 'Бронирование по запросу',
                            )
                          else
                            Text('Причина: $reason'),
                          if (plannedDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${[4, 5, 7].contains(status) ? 'Выдано до' : 'Запрос аренды до'} ${plannedDate.toString().substring(8, 10)}.${plannedDate.toString().substring(5, 7)}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          const SizedBox(height: 16),
                          if (status == 3)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton(
                                onPressed:
                                    () => _showRejectionDialog(requestId),
                                child: const Text('Отклонить'),
                              ),
                            )
                          else if ([4, 5, 7].contains(status))
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ElevatedButton(
                                onPressed:
                                    () => _changeReturnDateDialog(requestId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Изменить дату возврата'),
                              ),
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _updateStatus(requestId, 3),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Разрешить'),
                                ),
                                OutlinedButton(
                                  onPressed:
                                      () => _showRejectionDialog(requestId),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Отклонить'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/items'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.inventory, color: Colors.blue),
                    SizedBox(height: 4),
                    Text('Оборудование', style: TextStyle(color: Colors.blue)),
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
