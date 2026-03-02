import 'package:flutter/material.dart';

class ProfilePopup extends StatelessWidget {
  final String userName;
  final String userEmail;
  final bool isAdmin;
  final VoidCallback onOpenAdminPanel;
  final VoidCallback onOpenPersonalisation;
  final VoidCallback onOpenStatistics;
  final VoidCallback onSignOut;

  const ProfilePopup({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.isAdmin,
    required this.onOpenAdminPanel,
    required this.onOpenPersonalisation,
    required this.onOpenStatistics,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial =
        userName.trim().isNotEmpty ? userName.trim()[0].toUpperCase() : '?';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 20,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color.fromARGB(255, 126, 233, 3),
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  'Dostępny',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (isAdmin)
              _ProfileMenuRow(
                icon: Icons.admin_panel_settings,
                text: 'Panel Administratora',
                onTap: isAdmin ? onOpenAdminPanel : null,
              ),
            _ProfileMenuRow(
              icon: Icons.color_lens,
              text: 'Personalizacja',
              onTap: onOpenPersonalisation,
            ),
            if (!isAdmin)
              _ProfileMenuRow(
                icon: Icons.bar_chart,
                text: 'Statystyki',
                onTap: onOpenStatistics,
              ),
            _ProfileMenuRow(
              icon: Icons.logout,
              text: 'Wyloguj się',
              onTap: onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _ProfileMenuRow({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 14, color: colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
