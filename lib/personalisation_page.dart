import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_manager.dart';

class PersonalisationPage extends StatelessWidget {
  const PersonalisationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizacja motywu'),
        backgroundColor: themeProvider.accentColor,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Wybierz kolor akcentu:',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: colors.map((color) {
                  return GestureDetector(
                    onTap: () {
                      themeProvider.setAccentColor(color);
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: themeProvider.accentColor == color
                              ? Colors.black
                              : Colors.transparent,
                          width: 4,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
