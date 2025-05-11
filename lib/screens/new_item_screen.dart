import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NewItemScreen extends StatefulWidget {
  const NewItemScreen({super.key});

  @override
  State<NewItemScreen> createState() => _NewItemScreenState();
}

class _NewItemScreenState extends State<NewItemScreen> {
  final _formKey = GlobalKey<FormState>();
  String invKey = '';
  String name = '';
  String owner = '';
  int? cellId;
  bool accessIsRequest = false;
  List<Map<String, String>> specs = [
    {'key': '', 'value': ''},
  ];
  List<dynamic> availableCells = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCells();
  }

  Future<void> _loadCells() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final res = await http.get(
      Uri.parse('https://hsesmartlocker.ru/cells/available/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      setState(() {
        availableCells = json.decode(utf8.decode(res.bodyBytes));
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final Map<String, String> finalSpecs = {
      for (var s in specs) s['key']!: s['value']!,
    };

    final data = {
      'inv_key': invKey,
      'name': name,
      'owner': owner,
      'status': 1,
      'available': true,
      'access_level': accessIsRequest ? 2 : 1,
      'specifications': finalSpecs,
      if (cellId != null) 'cell': cellId,
    };

    final res = await http.post(
      Uri.parse('https://hsesmartlocker.ru/items/new'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (res.statusCode == 200) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка при создании'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.blue, fontSize: 15),
    border: InputBorder.none,
    isDense: true,
    contentPadding: EdgeInsets.zero,
  );

  Widget _inputBlock({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.lightBlue.shade100),
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
    ),
    child: child,
  );

  Widget _buildSpecFields() {
    return Column(
      children: [
        for (int i = 0; i < specs.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.lightBlue.shade100),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    style: const TextStyle(fontSize: 15),
                    cursorColor: Colors.blue,
                    decoration: _inputDecoration('Параметр *'),
                    initialValue: specs[i]['key'],
                    onSaved: (v) => specs[i]['key'] = v ?? '',
                    validator:
                        (v) =>
                            v == null || v.isEmpty ? 'Обязательное поле' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    style: const TextStyle(fontSize: 15),
                    cursorColor: Colors.blue,
                    decoration: _inputDecoration('Значение *'),
                    initialValue: specs[i]['value'],
                    onSaved: (v) => specs[i]['value'] = v ?? '',
                    validator:
                        (v) =>
                            v == null || v.isEmpty ? 'Обязательное поле' : null,
                  ),
                ),
                const SizedBox(width: 8),
                if (i > 0)
                  IconButton(
                    onPressed: () => setState(() => specs.removeAt(i)),
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                  ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                () => setState(() => specs.add({'key': '', 'value': ''})),
            icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
            label: const Text(
              'Добавить параметры',
              style: TextStyle(color: Colors.blue),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.blue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        title: const Text(
          'Новое оборудование',
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
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              )
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Обязательные поля помечены *',
                          style: TextStyle(fontSize: 13, color: Colors.blue),
                        ),
                      ),
                      _inputBlock(
                        child: TextFormField(
                          style: const TextStyle(fontSize: 15),
                          cursorColor: Colors.blue,
                          decoration: _inputDecoration('Инвентарный номер *'),
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? 'Обязательное поле'
                                      : null,
                          onSaved: (v) => invKey = v ?? '',
                        ),
                      ),
                      _inputBlock(
                        child: TextFormField(
                          style: const TextStyle(fontSize: 15),
                          cursorColor: Colors.blue,
                          decoration: _inputDecoration('Название *'),
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? 'Обязательное поле'
                                      : null,
                          onSaved: (v) => name = v ?? '',
                        ),
                      ),
                      _inputBlock(
                        child: TextFormField(
                          style: const TextStyle(fontSize: 15),
                          cursorColor: Colors.blue,
                          decoration: _inputDecoration('Ответственный *'),
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? 'Обязательное поле'
                                      : null,
                          onSaved: (v) => owner = v ?? '',
                        ),
                      ),
                      _inputBlock(
                        child: DropdownButtonFormField<int>(
                          decoration: InputDecoration(
                            labelText: 'Ячейка (если есть)',
                            labelStyle: const TextStyle(color: Colors.blue),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                            color: Colors.black,
                          ), // ← Черный текст
                          items:
                              availableCells.map<DropdownMenuItem<int>>((cell) {
                                return DropdownMenuItem(
                                  value: cell['id'],
                                  child: Text(
                                    'Ячейка ${cell['id']} (${cell['size']})',
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) => setState(() => cellId = value),
                        ),
                      ),
                      _inputBlock(
                        child: Row(
                          children: [
                            const Text(
                              'Доступ только по запросу?',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            ToggleButtons(
                              isSelected: [accessIsRequest, !accessIsRequest],
                              onPressed: (int index) {
                                setState(() {
                                  accessIsRequest = index == 0;
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              borderColor: Colors.blue.shade100,
                              selectedColor: Colors.white,
                              fillColor: Colors.blue,
                              color: Colors.blue,
                              selectedBorderColor: Colors.blue,
                              constraints: const BoxConstraints(
                                minWidth: 60,
                                minHeight: 36,
                              ),
                              children: const [Text('Да'), Text('Нет')],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSpecFields(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Создать',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
