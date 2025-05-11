import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

Timer? _pollingTimer;
String? _currentStatus;

const kPrimaryColor = Color(0xFF0EBEFF);
const kErrorColor = Color(0xFFFF3B30);
const kButtonSpacing = 16.0;

class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({super.key});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  late Map<String, dynamic> _booking;
  String? _code;
  bool _loadingCode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _booking =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _currentStatus = (_booking['status'] ?? '').toString().toLowerCase();
    _startPolling();
  }

  Future<void> _getCode() async {
    setState(() => _loadingCode = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final id = _booking['id'];
    final res = await http.post(
      Uri.parse('https://hsesmartlocker.ru/requests/$id/generate-code'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = json.decode(utf8.decode(res.bodyBytes));
      setState(() {
        _code = data['code'];
        _loadingCode = false;
      });
    } else {
      _snack('Не удалось получить код');
      setState(() => _loadingCode = false);
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final res = await http.get(
        Uri.parse('https://hsesmartlocker.ru/requests/my'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final all = json.decode(utf8.decode(res.bodyBytes)) as List;

        final updated = all.firstWhere(
          (r) => r['id'] == _booking['id'],
          orElse: () => null,
        );

        if (updated == null) {
          _pollingTimer?.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Заявка была удалена или завершена'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/booking',
              (_) => false,
            );
          }
          return;
        }

        final newStatus = (updated['status'] ?? '').toString().toLowerCase();
        if (newStatus != _currentStatus) {
          _pollingTimer?.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Статус обновлён: $newStatus'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/booking',
              (_) => false,
            );
          }
        }
      }
    });
  }

  Future<void> _cancel() async {
    if (!await _confirm()) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final id = _booking['id'];
    final res = await http.post(
      Uri.parse('https://hsesmartlocker.ru/requests/$id/cancel'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      Navigator.pop(context, true);
      _snack('Бронирование отменено');
    } else {
      _snack('Ошибка при отмене');
    }
  }

  void _snack(String t) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(t), backgroundColor: Colors.red));

  Future<bool> _confirm() => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder:
        (c) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Отменить бронирование?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Вы уверены, что хотите отменить текущую заявку?',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _outlineBtn('Нет', () => Navigator.pop(c, false)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _filledBtn(
                        'Да',
                        () => Navigator.pop(c, true),
                        color: kErrorColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
  ).then((v) => v ?? false);

  Widget _header() {
    final name = _booking['item_name'] ?? 'Оборудование';
    final specs = _booking['item_specs'] as Map<String, dynamic>?;

    return Column(
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: kPrimaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (specs != null && specs.isNotEmpty)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children:
                  specs.entries.map((e) {
                    return Column(
                      children: [
                        Container(
                          width: double.infinity,
                          color: kPrimaryColor.withOpacity(0.05),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          child: Text(
                            '${e.key}: ${e.value}',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: kPrimaryColor.withOpacity(0.2),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _codeBlock({bool forReturn = false}) => Column(
    children: [
      Text(
        forReturn ? 'Код для возврата:' : 'Ваш код:',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Text(
        _code ?? '••••',
        style: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: _code != null ? kPrimaryColor : Colors.grey.shade400,
          letterSpacing: 6,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Код действителен 3 минуты',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
      const SizedBox(height: kButtonSpacing),
      _filledBtn(
        _code == null ? ('Получить код') : 'Обновить код',
        _loadingCode ? null : _getCode,
        loading: _loadingCode,
      ),
    ],
  );

  Widget _alert(String txt, {Color color = kErrorColor}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      txt,
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    ),
  );

  Widget _filledBtn(
    String t,
    VoidCallback? onTap, {
    bool loading = false,
    Color color = kPrimaryColor,
  }) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child:
          loading
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Text(t),
    ),
  );

  Widget _outlineBtn(
    String t,
    VoidCallback? onTap, {
    Color color = kPrimaryColor,
  }) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color, width: 2),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: Colors.white,
      ),
      child: Text(t),
    ),
  );

  Widget _infoFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/about_locker'),
        child: Text(
          'Где SmartLocker?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: kPrimaryColor,
          ),
        ),
      ),
    );
  }

  Widget _returnDateCard(String formatted) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(12),
    child: Text(
      'Срок возврата: $formatted',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Colors.black87,
      ),
      textAlign: TextAlign.center,
    ),
  );

  Widget _content() {
    final status = (_booking['status'] ?? '').toString().toLowerCase();

    final plannedDate = DateTime.tryParse(
      _booking['planned_return_date'] ?? '',
    )?.add(const Duration(hours: 3));
    final formatted =
        plannedDate != null
            ? DateFormat('dd.MM.yyyy HH:mm').format(plannedDate)
            : '';
    final now = DateTime.now();
    final near =
        plannedDate != null && plannedDate.difference(now).inHours <= 24;
    final overdue = plannedDate != null && plannedDate.isBefore(now);

    if (status == 'создана') {
      return Column(
        children: [
          const Text(
            'Заявка будет рассмотрена в течение 24 часов.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: kButtonSpacing),
          _filledBtn(
            'Написать в поддержку',
            () => Navigator.pushNamed(context, '/support'),
          ),
          const SizedBox(height: kButtonSpacing),
          _outlineBtn('Отменить бронирование', _cancel, color: kErrorColor),
        ],
      );
    }

    if (status == 'ожидает получения') {
      return Column(
        children: [
          _codeBlock(),
          const SizedBox(height: kButtonSpacing),
          _outlineBtn('Отменить бронирование', _cancel, color: kErrorColor),
          _infoFooter(),
        ],
      );
    }

    if (status == 'выдано' ||
        status == 'ожидает возврата' ||
        status == 'просрочено') {
      final widgets = <Widget>[
        _codeBlock(forReturn: true),
        const SizedBox(height: kButtonSpacing),
        _filledBtn('Запросить продление', () async {
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now().add(const Duration(days: 1)),
            firstDate: DateTime.now().add(const Duration(days: 1)),
            lastDate: DateTime.now().add(const Duration(days: 60)),
            builder: (context, child) {
              return Theme(
                data: ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: kPrimaryColor,
                    onPrimary: Colors.white,
                  ),
                ),
                child: child!,
              );
            },
          );

          if (pickedDate != null) {
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString('token');
            final response = await http.post(
              Uri.parse(
                'https://hsesmartlocker.ru/requests/req_change_return_date',
              ),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'request_id': _booking['id'],
                'new_date': pickedDate.toIso8601String(),
              }),
            );

            if (!mounted) return;

            if (response.statusCode == 200) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Ваша заявка на продление срока возврата будет рассмотрена в течение 24 часов',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              _snack('Ошибка при отправке запроса');
            }
          }
        }),
        const SizedBox(height: kButtonSpacing),
        if (status == 'ожидает возврата' && near && !overdue)
          _alert('Верните оборудование до $formatted', color: kPrimaryColor),
        if (status == 'просрочено' || overdue)
          _alert('Срочно верните оборудование', color: kErrorColor),
        const SizedBox(height: 16),
        if (formatted.isNotEmpty) _returnDateCard(formatted),
        _infoFooter(),
      ];
      return Column(children: widgets);
    }

    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: kPrimaryColor,
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [_header(), const SizedBox(height: 32), _content()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
