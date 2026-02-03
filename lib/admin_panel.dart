import 'package:flutter/material.dart';

import 'questions_panel.dart';
import 'widgets/admin_tiles.dart';
import 'admin_stats.dart';
import 'manage_admins.dart';
import 'CreatingTestsAndReportsPage.dart';

class AdminPanelPage extends StatelessWidget {
  const AdminPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final adminTiles = <AdminTileData>[
      AdminTileData(
        icon: Icons.people,
        label: 'Administratorzy',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageAdminsPage()),
          );
        },
      ),
      AdminTileData(
        icon: Icons.bar_chart,
        label: 'Raporty i statystyki',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminStatsPage()),
          );
        },
      ),
      AdminTileData(
        icon: Icons.troubleshoot_rounded,
        label: 'Statystyki trudności pytań',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => QuestionStatsPage()),
          );
        },
      ),
      AdminTileData(
        icon: Icons.play_circle_fill,
        label: 'Przeprowadź test',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreatingTestsAndReportsPage(),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Administratora'),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Witaj w panelu administratora',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),

          LayoutBuilder(
            builder: (context, constraints) {
              int columns = 1;
              if (constraints.maxWidth > 1000) {
                columns = 3;
              } else if (constraints.maxWidth > 700) {
                columns = 2;
              }

              final availableWidth =
                  constraints.maxWidth - (20 * (columns - 1));
              final tileWidth =
                  (availableWidth / columns).clamp(0, 300).toDouble();

              return Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children:
                    adminTiles.map((data) {
                      return SizedBox(
                        width: tileWidth,
                        child: AdminTile(data: data),
                      );
                    }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
