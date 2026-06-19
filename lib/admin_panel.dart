import 'package:flutter/material.dart';

import 'question_panel.dart';
import 'utils/helpers.dart';
import 'widgets/admin_tiles.dart';
import 'admin_stats.dart';
import 'admin_management.dart';
import 'test_and_report_creation.dart';
import 'admin_qualifications.dart';

class AdminPanelPage extends StatelessWidget {
  final bool isSuperAdmin;
  final String currentUserEmail;

  const AdminPanelPage({
    super.key,
    required this.isSuperAdmin,
    required this.currentUserEmail,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;
    final hPad = width < 600 ? 16.0 : 24.0;

    final adminTiles = <AdminTileData>[
      AdminTileData(
        icon: Icons.people,
        label: 'Administratorzy',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ManageAdminsPage(
              isSuperAdmin: kUseFakeData ? true : isSuperAdmin,
              currentUserEmail: kUseFakeData
                  ? 'superadmin@zselektr.onmicrosoft.com'
                  : currentUserEmail,
            ),
          ),
        ),
      ),
      AdminTileData(
        icon: Icons.bar_chart,
        label: 'Raporty i statystyki',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminStatsPage()),
        ),
      ),
      AdminTileData(
        icon: Icons.troubleshoot_rounded,
        label: 'Dane trudności pytań',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QuestionStatsPage()),
        ),
      ),
      AdminTileData(
        icon: Icons.school_rounded,
        label: 'Kwalifikacje i zawody',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageQualificationsPage()),
        ),
      ),
      AdminTileData(
        icon: Icons.play_circle_fill,
        label: 'Przeprowadź test',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatingTestsAndReportsPage(
              isSuperAdmin: kUseFakeData ? true : isSuperAdmin,
              currentUserEmail: kUseFakeData
                  ? 'superadmin@zselektr.onmicrosoft.com'
                  : currentUserEmail,
            ),
          ),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Administratora'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        iconTheme: IconThemeData(color: cs.onPrimary),
      ),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 28),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: cs.onPrimary,
                    size: 48,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Witaj, Administratorze',
                        style: tt.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Zarządzaj użytkownikami, pytaniami i raportami.',
                        style: tt.bodyLarge?.copyWith(
                          color: cs.onPrimary.withValues(alpha: 0.78),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tiles ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'NARZĘDZIA',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                LayoutBuilder(
                  builder: (context, constraints) {
                    int columns = 1;
                    if (constraints.maxWidth > 1000) {
                      columns = 4;
                    } else if (constraints.maxWidth > 700) {
                      columns = 2;
                    }

                    final ratio = columns == 1 ? 4.8 : 3.0;

                    return GridView.count(
                      crossAxisCount: columns,
                      crossAxisSpacing: 36,
                      mainAxisSpacing: 36,
                      childAspectRatio: ratio,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: adminTiles
                          .map((data) => AdminTile(data: data))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
