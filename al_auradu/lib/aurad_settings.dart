import 'package:flutter/material.dart';
import 'aurad_theme.dart';
import 'store.dart';

/// Settings UI is local-only until a cloud account backend is configured.
class AuradSettingsScreen extends StatelessWidget {
  const AuradSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
                const _SectionHeading('Appearance'),
                AuradPanel(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      app.dark ? Icons.dark_mode_outlined : Icons.light_mode,
                    ),
                    title: const Text('Dark mode'),
                    subtitle: const Text('Saved on this device'),
                    value: app.dark,
                    onChanged: (_) => app.toggleDark(),
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionHeading('Reading'),
                const AuradPanel(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.menu_book_outlined),
                        title: Text('Quran and document readers'),
                        subtitle: Text(
                            'Continue using existing page navigation, '
                            'reader zoom and scroll controls.'),
                      ),
                      Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.bookmark_outline),
                        title: Text('Bookmarks'),
                        subtitle: Text('Stored locally on this device'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionHeading('Account and privacy'),
                const AuradPanel(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.shield_outlined),
                    title: Text('Guest reading'),
                    subtitle: Text(
                      'Reading requires no login. Cloud accounts and syncing '
                      'are not connected yet.',
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionHeading('About'),
                const AuradPanel(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline),
                    title: Text('AL AURADU'),
                    subtitle: Text('Islamic reading and devotional library'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuradAccountScreen extends StatelessWidget {
  const AuradAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('My Account')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AuradPanel(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundColor: AuradColors.emerald,
                        foregroundColor: Colors.white,
                        radius: 30,
                        child: const Icon(Icons.person_outline, size: 34),
                      ),
                      const SizedBox(height: 14),
                      Text('Guest reader',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        'Browse the Islamic library without an account.',
                        style: TextStyle(
                          color: AuradColors.secondaryText(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.bookmark_outline),
                        title: const Text('Saved bookmarks'),
                        trailing: Text(app.bookmarks.length.toString()),
                      ),
                      const Divider(),
                      const ListTile(
                        leading: Icon(Icons.cloud_off_outlined),
                        title: Text('Cloud sync'),
                        subtitle: Text('Not configured'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.login),
                        label: const Text('Login — available after backend setup'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This app does not currently have an authentication '
                        'service. No passwords or account details are '
                        'collected on this screen.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  const _SectionHeading(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
        child: Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                )),
      );
}
