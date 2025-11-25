import 'package:flutter/material.dart';

class ProfilePopup extends StatefulWidget {
  final String userName;
  final String userEmail;
  final bool isAdmin;
  final VoidCallback onClose;
  final VoidCallback onOpenAdminPanel;
  final VoidCallback onOpenPersonalisation;
  final VoidCallback onOpenStatistics;
  final VoidCallback onSignOut;
  final ColorScheme colorScheme;

  const ProfilePopup({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.isAdmin,
    required this.onClose,
    required this.onOpenAdminPanel,
    required this.onOpenPersonalisation,
    required this.onOpenStatistics,
    required this.onSignOut,
    required this.colorScheme,
  });

  @override
  State<ProfilePopup> createState() => _ProfilePopupState();
}

class _ProfilePopupState extends State<ProfilePopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.2, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 600 ? 300.0 : screenWidth * 0.9;

    return GestureDetector(
      onTap: widget.onClose,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          Positioned(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth,
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
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
                                  backgroundColor: widget.colorScheme.primary,
                                  child: Text(
                                    widget.userName[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: widget.colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.userName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: widget.colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        widget.userEmail,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: widget.colorScheme
                                              .onSurfaceVariant,
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
                                    color: widget.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(
                                height: 20, thickness: 1, color: Colors.grey),
                            Flexible(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    if (widget.isAdmin)
                                      _ProfileMenuRow(
                                        icon: Icons.admin_panel_settings,
                                        text: 'Panel Administratora',
                                        onTap: widget.onOpenAdminPanel,
                                      ),
                                    _ProfileMenuRow(
                                      icon: Icons.color_lens,
                                      text: 'Personalizacja',
                                      onTap: widget.onOpenPersonalisation,
                                    ),
                                    if(!widget.isAdmin)
                                    _ProfileMenuRow(
                                      icon: Icons.bar_chart,
                                      text: 'Statystyki',
                                      onTap: widget.onOpenStatistics,
                                    ),
                                    _ProfileMenuRow(
                                      icon: Icons.logout,
                                      text: 'Wyloguj się',
                                      onTap: widget.onSignOut,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _ProfileMenuRow({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
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
    );
  }
}
