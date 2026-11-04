import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/bloc/auth_bloc.dart';
import '../auth/data/auth_repository.dart';

/// App shell after sign-in. Each tab is owned by one team member (see README).
/// Placeholders are replaced by the real feature pages as they are built.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.session});

  final UserSession session;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <({IconData icon, String label, Widget page})>[
      (icon: Icons.home_outlined, label: 'Feed', page: const _Placeholder('Feed - post-service')),
      (icon: Icons.map_outlined, label: 'Map', page: const _Placeholder('Map - post-service')),
      (icon: Icons.chat_bubble_outline, label: 'Chat', page: const _Placeholder('Chat - chat-service')),
      (
        icon: Icons.notifications_none,
        label: 'Alerts',
        page: const _Placeholder('Notifications - notification-service'),
      ),
      (icon: Icons.person_outline, label: 'Profile', page: _ProfileTab(session: widget.session)),
      if (widget.session.isAdmin)
        (
          icon: Icons.admin_panel_settings_outlined,
          label: 'Admin',
          page: const _Placeholder('Admin - users & reports'),
        ),
    ];

    return Scaffold(
      body: SafeArea(child: tabs[_tab].page),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.icon), label: t.label)],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.session});

  final UserSession session;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('@${session.username}', style: Theme.of(context).textTheme.headlineSmall),
          Text(session.role),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(child: Text(text));
}
