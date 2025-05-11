import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  List<dynamic> items = [];
  Map<int, Map<String, dynamic>> issuedInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }

    setState(() => _isLoading = true);

    final itemsRes = await http.get(
      Uri.parse('https://hsesmartlocker.ru/items/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final reqsRes = await http.get(
      Uri.parse('https://hsesmartlocker.ru/requests/all'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (itemsRes.statusCode == 200) {
      final loadedItems = json.decode(utf8.decode(itemsRes.bodyBytes));
      final loadedReqs =
          reqsRes.statusCode == 200
              ? json.decode(utf8.decode(reqsRes.bodyBytes)) as List
              : [];

      final infoMap = <int, Map<String, dynamic>>{};
      final userCache = <int, String>{};

      for (var req in loadedReqs) {
        if ([1, 3, 4, 5, 7].contains(req['status'])) {
          final itemId = req['item_id'];
          final userId = req['user'];
          String userName;

          if (userCache.containsKey(userId)) {
            userName = userCache[userId]!;
          } else {
            final userRes = await http.get(
              Uri.parse('https://hsesmartlocker.ru/users/$userId'),
              headers: {'Authorization': 'Bearer $token'},
            );
            if (userRes.statusCode == 200) {
              final userData = json.decode(utf8.decode(userRes.bodyBytes));
              userName = userData['name'] ?? 'Неизвестно';
              userCache[userId] = userName;
            } else {
              userName = 'Неизвестно';
            }
          }

          infoMap[itemId] = {
            'name': userName,
            'returnDate': req['planned_return_date'],
          };
        }
      }

      loadedItems.sort((a, b) {
        final int aCell = (a['cell'] ?? 99999) as int;
        final int bCell = (b['cell'] ?? 99999) as int;
        return aCell.compareTo(bCell);
      });

      setState(() {
        items = List.from(loadedItems);
        issuedInfo = infoMap;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка при загрузке оборудования'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateItemStatus(int itemId, String action) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final endpoint = switch (action) {
      'delete' => 'delete',
      'broken' => 'broke',
      _ => null,
    };

    if (endpoint == null) return;

    final res = await http.post(
      Uri.parse('https://hsesmartlocker.ru/items/$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'item_id': itemId}),
    );

    if (res.statusCode == 200) {
      _loadItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${res.statusCode}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCellChangeDialog(int itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final res = await http.get(
      Uri.parse('https://hsesmartlocker.ru/cells/available/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось получить список ячеек'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final List cells = json.decode(utf8.decode(res.bodyBytes));
    int? selectedCell;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Выберите новую ячейку'),
              content: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.lightBlue.shade100),
                ),
                child: DropdownButtonFormField<int>(
                  value: selectedCell,
                  onChanged: (value) => setState(() => selectedCell = value),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black, fontSize: 15),
                  iconEnabledColor: Colors.blue,
                  items:
                      cells.map<DropdownMenuItem<int>>((cell) {
                        return DropdownMenuItem<int>(
                          value: cell['id'],
                          child: Text('Ячейка ${cell['id']} (${cell['size']})'),
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedCell == null) return;

                    Navigator.pop(context);

                    final changeRes = await http.post(
                      Uri.parse('https://hsesmartlocker.ru/items/change_cell'),
                      headers: {
                        'Authorization': 'Bearer $token',
                        'Content-Type': 'application/json',
                      },
                      body: jsonEncode({
                        'item_id': itemId,
                        'cell_id': selectedCell,
                      }),
                    );

                    if (changeRes.statusCode == 200) {
                      _loadItems();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ошибка при смене ячейки'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Подтвердить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showConfirmDialog(int itemId, String action, String message) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Нет'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _updateItemStatus(itemId, action);
              },
              child: const Text('Да'),
            ),
          ],
        );
      },
    );
  }

  String _statusText(int status, bool available) {
    return switch (status) {
      1 => 'Свободно',
      2 => 'Выдано',
      3 => 'Сломано',
      4 => 'Забронировано',
      _ => 'Неизвестно',
    };
  }

  Color _statusColor(int status, bool available) {
    return switch (status) {
      1 => Colors.green,
      2 => Colors.blue,
      3 => Colors.red,
      4 => Colors.blue,
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F6FB),
      appBar: AppBar(
        title: const Text(
          'Оборудование',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadItems),
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
              : ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final item = items[index];
                  final status = item['status'];
                  final specs = item['specifications'];
                  final available = item['available'] ?? true;
                  final disabled = status == 2 || status == 4;
                  final cell = item['cell'];
                  final name = item['name'] ?? 'Оборудование';
                  final id = item['id'];
                  final issued = issuedInfo[id];

                  String? formattedReturnDate;
                  if (issued?['returnDate'] != null) {
                    final dt = DateTime.tryParse(issued!['returnDate']);
                    if (dt != null) {
                      formattedReturnDate = DateFormat(
                        'dd.MM.yyyy HH:mm',
                      ).format(dt);
                    }
                  }

                  return Opacity(
                    opacity: disabled ? 0.5 : 1.0,
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (cell != null)
                              Text(
                                'Ячейка $cell',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _statusText(status, available),
                              style: TextStyle(
                                color: _statusColor(status, available),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (issued != null) ...[
                              const SizedBox(height: 6),
                              Text('Бронь: ${issued['name']}'),
                              if (formattedReturnDate != null)
                                Text('Дата возврата: $formattedReturnDate'),
                            ],
                            const SizedBox(height: 8),
                            if (specs is Map)
                              ...specs.entries.map(
                                (e) => Text('${e.key}: ${e.value}'),
                              ),
                            if (!disabled) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    onPressed:
                                        () => _showConfirmDialog(
                                          item['id'],
                                          'delete',
                                          'Удалить предмет?',
                                        ),
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    tooltip: 'Удалить',
                                  ),
                                  OutlinedButton(
                                    onPressed:
                                        () => _showConfirmDialog(
                                          item['id'],
                                          'broken',
                                          status == 3
                                              ? 'Отметить как исправное?'
                                              : 'Отметить как сломано?',
                                        ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: const BorderSide(
                                        color: Colors.blue,
                                      ),
                                    ),
                                    child: Text(
                                      status == 3 ? 'Исправно' : 'Сломано',
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed:
                                        () => _showCellChangeDialog(item['id']),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: const BorderSide(
                                        color: Colors.blue,
                                      ),
                                    ),
                                    child: const Text('Поменять ячейку'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/new_item'),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
        shape: const CircleBorder(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
