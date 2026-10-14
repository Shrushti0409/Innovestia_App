import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/routes/app_routes.dart';
import '../features/feature_screens.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.role});
  final UserRole role;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;
  bool _redirected = false;
  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    if (!auth.isAuthenticated || auth.user!.role != widget.role) {
      if (!_redirected) {
        _redirected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted)
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.welcome,
              (_) => false,
            );
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = [
      _Home(role: widget.role),
      const DiscoveryScreen(),
      const MessagesScreen(),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({required this.role});
  final UserRole role;
  @override
  Widget build(BuildContext context) {
    final isStartup = role == UserRole.startup;
    final isAdmin = role == UserRole.admin;
    final title = isAdmin
        ? 'Platform overview'
        : isStartup
        ? 'Your Startup'
        : 'Discover Startups';
    return Scaffold(
      appBar: AppBar(title: const Text('Innovestia')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Welcome to Innovestia',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            const _Stats(),
            const SizedBox(height: 28),
            const Text(
              'Quick actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (!isAdmin)
                  _Action(
                    icon: Icons.explore,
                    label: isStartup ? 'Find Investors' : 'Find Startups',
                    route: AppRoutes.discovery,
                  ),
                _Action(
                  icon: Icons.request_page_outlined,
                  label: 'Requests',
                  route: AppRoutes.requests,
                ),
                _Action(
                  icon: Icons.chat_outlined,
                  label: 'Messages',
                  route: AppRoutes.messages,
                ),
                if (isAdmin)
                  _Action(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'User Management',
                    route: AppRoutes.adminUsers,
                  ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Recent activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const _RecentActivity(),
            const SizedBox(height: 24),
            const Text(
              'Recent messages',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const _RecentMessages(),
          ],
        ),
      ),
    );
  }
}

class _RecentMessages extends StatefulWidget {
  const _RecentMessages();
  @override
  State<_RecentMessages> createState() => _RecentMessagesState();
}

class _RecentMessagesState extends State<_RecentMessages> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final r = await AuthScope.of(context).api.get('/conversations');
      final d = r['data'];
      final raw = d is Map ? d['items'] : null;
      if (mounted)
        setState(
          () => _items = raw is List
              ? raw.whereType<Map<String, dynamic>>().take(3).toList()
              : [],
        );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Card(
        child: ListTile(
          leading: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Loading messages'),
        ),
      );
    if (_error != null)
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: const Text('Messages unavailable'),
          subtitle: Text(_error!),
        ),
      );
    if (_items.isEmpty)
      return const Card(
        child: ListTile(
          leading: Icon(Icons.chat_bubble_outline),
          title: Text('No recent messages'),
        ),
      );
    return Column(
      children: _items.map((item) {
        final participants = item['participants'] is List
            ? (item['participants'] as List)
                  .whereType<Map<String, dynamic>>()
                  .toList()
            : <Map<String, dynamic>>[];
        final myId = AuthScope.of(context).user?.id;
        final others = participants
            .where((p) => p['_id'] != myId && p['id'] != myId)
            .toList();
        final last = item['lastMessage'];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(
              others.isEmpty
                  ? 'Conversation'
                  : others.first['name']?.toString() ?? 'Member',
            ),
            subtitle: Text(
              last is Map
                  ? last['body']?.toString() ?? ''
                  : 'Open your conversation',
            ),
            onTap: () => Navigator.pushNamed(context, AppRoutes.messages),
          ),
        );
      }).toList(),
    );
  }
}

class _Stats extends StatefulWidget {
  const _Stats();
  @override
  State<_Stats> createState() => _StatsState();
}

class _StatsState extends State<_Stats> {
  List<String> _labels = const [];
  List<String> _values = const [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final result = await AuthScope.of(context).api.get('/dashboard');
      final data = result['data'];
      final raw = data is Map ? data['items'] : null;
      final rows = raw is List ? raw.whereType<Map>().toList() : <Map>[];
      if (mounted)
        setState(() {
          _labels = rows.map((row) => row['label']?.toString() ?? '').toList();
          _values = rows.map((row) => row['value']?.toString() ?? '0').toList();
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _labels = ['Dashboard'];
          _values = ['Unavailable'];
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: ListTile(
          leading: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Loading dashboard summary'),
        ),
      );
    }
    if (_labels.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.insights_outlined),
          title: Text('Dashboard summary unavailable'),
          subtitle: Text('Try again when the backend is available.'),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final columns = (constraints.maxWidth / 150)
            .floor()
            .clamp(1, 3)
            .toInt();
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(_labels.length, (index) {
            return SizedBox(
              width: width,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _values[index],
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(_labels[index], maxLines: 2),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _RecentActivity extends StatefulWidget {
  const _RecentActivity();
  @override
  State<_RecentActivity> createState() => _RecentActivityState();
}

class _RecentActivityState extends State<_RecentActivity> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final result = await AuthScope.of(context).api.get('/notifications');
      final data = result['data'];
      final raw = data is Map ? data['items'] : null;
      if (mounted) {
        setState(() {
          _items = raw is List
              ? raw.whereType<Map<String, dynamic>>().take(3).toList()
              : [];
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to load recent activity.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _loading
      ? const Card(
          child: ListTile(
            leading: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Loading activity...'),
          ),
        )
      : _error != null
      ? Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: const Text('Recent activity unavailable'),
            subtitle: Text(_error!),
            trailing: IconButton(
              tooltip: 'Retry',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ),
        )
      : _items.isEmpty
      ? const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('No recent activity'),
            subtitle: Text('New updates will appear here.'),
          ),
        )
      : Column(
          children: _items
              .map(
                (item) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.notifications_none),
                    title: Text(item['title']?.toString() ?? 'Activity'),
                    subtitle: Text(item['body']?.toString() ?? ''),
                  ),
                ),
              )
              .toList(),
        );
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.route});
  final IconData icon;
  final String label, route;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 155,
    child: OutlinedButton.icon(
      onPressed: () => Navigator.pushNamed(context, route),
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
    ),
  );
}
