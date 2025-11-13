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
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              themeProvider.primaryColor.withValues(alpha: 0.08),
              themeProvider.secondaryColor.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AnimatedOpacity(
                    opacity: 1,
                    duration: Duration(milliseconds: 200),
                    child: Text(
                      'Wybierz kolor akcentu:',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Color options
                  Wrap(
                    spacing: 22,
                    runSpacing: 22,
                    alignment: WrapAlignment.center,
                    children:
                        colorMap.keys.map((primaryColor) {
                          final isSelected =
                              themeProvider.primaryColor == primaryColor;

                          return TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOutCubic,
                            tween: Tween<double>(
                              begin: 1.0,
                              end: isSelected ? 1.15 : 1.0,
                            ),
                            builder:
                                (context, scale, child) => GestureDetector(
                                  onTap: () {
                                    themeProvider.setAccentColor(
                                      primaryColor,
                                      colorMap[primaryColor]!,
                                    );
                                  },
                                  child: Transform.scale(
                                    scale: scale,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOutCubic,
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          if (isSelected)
                                            BoxShadow(
                                              color: primaryColor.withValues(
                                                alpha: 0.6,
                                              ),
                                              blurRadius: 16,
                                              spreadRadius: 4,
                                            ),
                                        ],
                                        border: Border.all(
                                          color: Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          );
                        }).toList(),
                  ),

                  const SizedBox(height: 50),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: themeProvider.secondaryColor.withValues(
                        alpha: 0.08,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: themeProvider.primaryColor,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOutCubic,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: themeProvider.primaryColor,
                          ),
                          child: const Text('Podgląd motywu'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOutCubic,
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeProvider.primaryColor
                                      .withValues(alpha: 0.9),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Przycisk'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOutCubic,
                              child: OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: themeProvider.primaryColor,
                                  side: BorderSide(
                                    color: themeProvider.primaryColor,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Drugi przycisk'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
