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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final initial =
        userName.trim().isNotEmpty ? userName.trim()[0].toUpperCase() : '?';

    return Material(
      elevation: 8,
      shadowColor: cs.shadow.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(16),
      color: cs.surface,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── User identity header ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer,
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
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userEmail,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (isAdmin) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Administrator',
                              style: tt.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSecondaryContainer,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),

            // ── Menu items ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  if (isAdmin)
                    _MenuItem(
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'Panel Administratora',
                      onTap: onOpenAdminPanel,
                      cs: cs,
                      tt: tt,
                    ),
                  //if (!isAdmin)
                    _MenuItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Statystyki',
                      onTap: onOpenStatistics,
                      cs: cs,
                      tt: tt,
                    ),
                  _MenuItem(
                    icon: Icons.palette_rounded,
                    label: 'Personalizacja',
                    onTap: onOpenPersonalisation,
                    cs: cs,
                    tt: tt,
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),

            // ── Sign out ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _MenuItem(
                icon: Icons.logout_rounded,
                label: 'Wyloguj się',
                onTap: onSignOut,
                cs: cs,
                tt: tt,
                destructive: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//                Menu item row
// ─────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
    required this.tt,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final ColorScheme cs;
  final TextTheme tt;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? cs.error : cs.onSurfaceVariant;
    final labelColor = destructive ? cs.error : cs.onSurface;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: tt.bodyMedium?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
