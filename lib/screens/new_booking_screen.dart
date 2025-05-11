import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewBookingScreen extends StatefulWidget {
  const NewBookingScreen({super.key});

  @override
  _NewBookingScreenState createState() => _NewBookingScreenState();
}

class _NewBookingScreenState extends State<NewBookingScreen> {
  List<dynamic> _equipment = [];
  List<dynamic> _filteredEquipment = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadEquipment();
    _searchController.addListener(_filterEquipment);
  }

  Future<void> _loadEquipment() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('https://hsesmartlocker.ru/items/available'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        _equipment = data;
        _filteredEquipment = data;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось загрузить оборудование'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterEquipment() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredEquipment =
          _equipment
              .where(
                (item) => item['name'].toString().toLowerCase().contains(query),
              )
              .toList();
    });
  }

  void _handleBooking(
    Map<String, dynamic> item,
    String justification,
    DateTime? selectedDate,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final plannedReturn =
        item['access_level'] == 1
            ? DateTime.now().add(const Duration(days: 3))
            : selectedDate!.copyWith(hour: 18, minute: 0);

    final body = {
      'item_id': item['id'],
      'planned_return_date': plannedReturn.toIso8601String(),
      'comment': justification,
    };

    final response = await http.post(
      Uri.parse('https://hsesmartlocker.ru/requests/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Бронирование успешно'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/booking', (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка при бронировании'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBookingDialog(Map<String, dynamic> equipment) {
    final specs =
        (equipment['specifications'] as Map<String, dynamic>?)?.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', ') ??
        'Нет данных';

    final isAuto = equipment['access_level'] == 1;
    final TextEditingController reasonController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  equipment['name'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  specs,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Text(
                  isAuto
                      ? 'Оборудование необходимо забрать в течение 24 часов и вернуть до 21:00 ${DateFormat('dd.MM').format(DateTime.now().add(const Duration(days: 3)))}. '
                          'Вы cможете запросить продление срока.'
                      : 'Укажите цель использования и дату возврата — заявка будет рассмотрена в течение 24 часов.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                if (!isAuto) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Обоснование необходимости',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (context, setStateDialog) {
                      return ElevatedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                            firstDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  dialogBackgroundColor: Colors.white,
                                  colorScheme: ColorScheme.light(
                                    primary: Colors.blue,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setStateDialog(() => selectedDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          selectedDate != null
                              ? 'Дата возврата: ${DateFormat('dd.MM.yyyy').format(selectedDate!)}'
                              : 'Выбрать дату возврата',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue,
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (!isAuto) {
                      final justification = reasonController.text.trim();
                      if (justification.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Пожалуйста, укажите обоснование'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (selectedDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Пожалуйста, выберите дату возврата'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                    }
                    Navigator.pop(context);
                    _handleBooking(
                      equipment,
                      reasonController.text.trim(),
                      selectedDate,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Забронировать'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F1F9),
      appBar: AppBar(
        title: const Text('Новое бронирование'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Поиск оборудования',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child:
                  _filteredEquipment.isEmpty
                      ? const Center(child: Text('Оборудование не найдено'))
                      : ListView.builder(
                        itemCount: _filteredEquipment.length,
                        itemBuilder: (context, index) {
                          final item = _filteredEquipment[index];
                          final isAuto = item['access_level'] == 1;
                          final status =
                              isAuto
                                  ? 'Можно забрать через 15 минут'
                                  : 'Доступно только по заявке';
                          final statusIcon =
                              isAuto ? Icons.bolt : Icons.edit_calendar;

                          final specs =
                              (item['specifications'] as Map<String, dynamic>?)
                                  ?.entries
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join(', ') ??
                              '';

                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              leading: Icon(
                                statusIcon,
                                color: isAuto ? Colors.green : Colors.orange,
                              ),
                              title: Text(
                                item['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    status,
                                    style: TextStyle(
                                      color:
                                          isAuto ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                  if (specs.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        specs,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () => _showBookingDialog(item),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
