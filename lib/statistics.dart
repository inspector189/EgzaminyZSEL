import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StatisticsPage extends StatelessWidget {
  final bool isDarkMode;

  const StatisticsPage({
    super.key,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statystyki'),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.blue,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchStatistics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Błąd: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Brak danych statystycznych.'));
          }

          final stats = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const Text(
                'Statystyki użytkownika',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...stats.entries.map((entry) {
                return ListTile(
                  title: Text(entry.key),
                  trailing: Text(entry.value.toString()),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> fetchStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? 'anonymous';

    if (userName == 'anonymous') {
      throw Exception('Proszę się zalogować, aby zobaczyć statystyki');
    }

    final url = Uri.parse('https://interpage.pl/egzaminy/stats.php');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Bearer zT93@rPcV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
      },
      body: {
        'userName': userName,
      },
    );

    print('📥 Statistics response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.containsKey('error')) {
        throw Exception(data['error']);
      }
      return data;
    } else {
      throw Exception('Nie udało się pobrać statystyk: ${response.statusCode} - ${response.body}');
    }
  }
}