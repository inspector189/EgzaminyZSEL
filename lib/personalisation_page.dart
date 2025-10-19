import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_manager.dart';

class PersonalisationPage extends StatelessWidget {
  const PersonalisationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final colorMap = {
      Colors.red: Colors.redAccent,
      Colors.blue: Colors.blueAccent,
      Colors.green: Colors.greenAccent,
      Colors.orange: Colors.orangeAccent,
      Colors.purple: Colors.purpleAccent,
      Colors.teal: Colors.tealAccent,
      Colors.pink: Colors.pinkAccent,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizacja motywu'),
        backgroundColor: themeProvider.primaryColor,
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
                children:
                    colorMap.keys.map((primaryColor) {
                      return GestureDetector(
                        onTap: () {
                          themeProvider.setAccentColor(
                            primaryColor,
                            colorMap[primaryColor]!,
                          );
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  themeProvider.primaryColor == primaryColor
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
