import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../app.dart';
import '../../core/routes/app_routes.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../core/utils/validators.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key, this.initialSaved = false});
  final bool initialSaved;
  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _saved = [];
  bool _showSaved = false;
  @override
  void initState() {
    super.initState();
    _showSaved = widget.initialSaved;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = AuthScope.of(context).user?.role;
      final type = role == UserRole.startup ? 'INVESTOR' : 'STARTUP';
      final q = _search.text.trim();
      final result = await AuthScope.of(context).api.get(
        '/profiles?type=$type${q.isEmpty ? '' : '&q=${Uri.encodeQueryComponent(q)}'}',
      );
      final savedResult = await AuthScope.of(
        context,
      ).api.get('/profiles/saved');
      final data = result['data'];
      final items = data is Map ? data['items'] : null;
      final savedData = savedResult['data'];
      final savedItems = savedData is Map ? savedData['items'] : null;
      if (mounted)
        setState(() {
          _profiles = items is List
              ? items.whereType<Map<String, dynamic>>().toList()
              : [];
          _saved = savedItems is List
              ? savedItems.whereType<Map<String, dynamic>>().toList()
              : [];
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error is ApiException
              ? error.message
              : 'Unable to load profiles.';
          _loading = false;
        });
    }
  }

  void _showProfile(Map<String, dynamic> profile, String profileId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile['name']?.toString() ?? 'Member',
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  profile['description']?.toString() ??
                      'No description provided.',
                ),
                const SizedBox(height: 8),
                Text(
                  [
                        profile['industry'],
                        profile['location'],
                        profile['businessStage'],
                      ]
                      .where((v) => v != null && v.toString().isNotEmpty)
                      .join(' · '),
                ),
                if (profile['pitch'] is Map &&
                    (profile['pitch'] as Map)['title'] != null)
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf),
                    title: Text((profile['pitch'] as Map)['title'].toString()),
                    subtitle: Text(
                      (profile['pitch'] as Map)['summary']?.toString() ??
                          'Pitch deck available',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      tooltip: 'Download pitch deck',
                      onPressed: () async {
                        try {
                          final bytes = await AuthScope.of(
                            sheetContext,
                          ).api.getBytes('/profiles/$profileId/pitch-deck');
                          await FilePicker.platform.saveFile(
                            fileName:
                                '${profile['name']?.toString() ?? 'startup'}-pitch-deck.pdf',
                            bytes: bytes,
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                          );
                        } catch (e) {
                          if (sheetContext.mounted)
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e is ApiException
                                      ? e.message
                                      : 'Unable to download pitch deck.',
                                ),
                              ),
                            );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthScope.of(context).user?.role;
    final label = role == UserRole.startup ? 'Investors' : 'Startups';
    return Scaffold(
      appBar: AppBar(
        title: Text('Discover $label'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showSaved = !_showSaved),
            child: Text(_showSaved ? 'Discover' : 'Saved (${_saved.length})'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_showSaved)
              TextField(
                controller: _search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search $label by name, industry or location',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _load,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _ErrorState(message: _error!, onRetry: _load)
                  : (_showSaved ? _saved : _profiles).isEmpty
                  ? _Empty(
                      title: _showSaved
                          ? 'No saved profiles'
                          : 'No $label found',
                      subtitle: _showSaved
                          ? 'Save a profile to find it here.'
                          : 'Try another search or check back later.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: (_showSaved ? _saved : _profiles).length,
                        itemBuilder: (context, index) {
                          final profile = (_showSaved
                              ? _saved
                              : _profiles)[index];
                          final profileId = profile['_id']?.toString() ?? '';
                          final isSaved = _saved.any(
                            (p) => p['_id']?.toString() == profileId,
                          );
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.business_outlined),
                              ),
                              title: Text(
                                profile['name']?.toString() ??
                                    'Innovestia member',
                              ),
                              subtitle: Text(
                                [
                                      profile['industry'],
                                      profile['location'],
                                      profile['businessStage'],
                                    ]
                                    .where(
                                      (v) =>
                                          v != null && v.toString().isNotEmpty,
                                    )
                                    .join(' · '),
                              ),
                              onTap: () => _showProfile(profile, profileId),
                              trailing: Wrap(
                                spacing: 0,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isSaved
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                    ),
                                    tooltip: isSaved
                                        ? 'Remove saved profile'
                                        : 'Save profile',
                                    onPressed: () async {
                                      try {
                                        if (isSaved) {
                                          await AuthScope.of(
                                            context,
                                          ).api.delete(
                                            '/profiles/$profileId/saved',
                                          );
                                        } else {
                                          await AuthScope.of(context).api.put(
                                            '/profiles/$profileId/saved',
                                          );
                                        }
                                        await _load();
                                      } catch (e) {
                                        if (context.mounted)
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e is ApiException
                                                    ? e.message
                                                    : 'Unable to save profile.',
                                              ),
                                            ),
                                          );
                                      }
                                    },
                                  ),
                                  if (AuthScope.of(context).user?.role ==
                                      UserRole.investor)
                                    IconButton(
                                      icon: const Icon(Icons.favorite_border),
                                      tooltip: 'Express interest',
                                      onPressed: () async {
                                        try {
                                          await AuthScope.of(context).api.post(
                                            '/startups/${profile['user']}/interests',
                                            body: {},
                                          );
                                          if (context.mounted)
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('Interest sent.'),
                                              ),
                                            );
                                        } catch (e) {
                                          if (context.mounted)
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  e is ApiException
                                                      ? e.message
                                                      : 'Unable to send interest.',
                                                ),
                                              ),
                                            );
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await AuthScope.of(context).api.get('/investment-requests');
      final d = r['data'];
      final v = d is Map ? d['items'] : null;
      if (mounted)
        setState(() {
          _items = v is List
              ? v.whereType<Map<String, dynamic>>().toList()
              : [];
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e is ApiException ? e.message : 'Unable to load requests.';
          _loading = false;
        });
    }
  }

  Future<void> _update(String id, String status) async {
    try {
      await AuthScope.of(
        context,
      ).api.put('/investment-requests/$id', body: {'status': status});
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Unable to update request.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Investment requests'),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _ErrorState(message: _error!, onRetry: _load)
        : _items.isEmpty
        ? const _Empty(
            title: 'No investment requests',
            subtitle: 'New investment interest will appear here.',
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              children: _items.map((item) {
                final startup = item['startup'];
                final investor = item['investor'];
                final other =
                    AuthScope.of(context).user?.role == UserRole.startup
                    ? investor
                    : startup;
                final status = item['status']?.toString() ?? 'PENDING';
                return Card(
                  child: ListTile(
                    title: Text(
                      other is Map
                          ? other['name']?.toString() ?? 'Member'
                          : 'Investment request',
                    ),
                    subtitle: Text('${item['message'] ?? ''}\n$status'),
                    isThreeLine: true,
                    trailing:
                        AuthScope.of(context).user?.role == UserRole.startup &&
                            status == 'PENDING'
                        ? PopupMenuButton<String>(
                            onSelected: (v) =>
                                _update(item['_id'].toString(), v),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'ACCEPTED',
                                child: Text('Accept'),
                              ),
                              PopupMenuItem(
                                value: 'REJECTED',
                                child: Text('Decline'),
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
  );
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _search = TextEditingController();
  bool _loading = true, _searching = false;
  String? _error;
  List<Map<String, dynamic>> _items = [], _matches = [];
  Timer? _poll;
  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _find(String value) async {
    final q = value.trim();
    if (q.isEmpty) {
      setState(() => _matches = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final r = await AuthScope.of(
        context,
      ).api.get('/chat/users?q=${Uri.encodeQueryComponent(q)}');
      final d = r['data'];
      final v = d is Map ? d['items'] : null;
      if (mounted)
        setState(
          () => _matches = v is List
              ? v.whereType<Map<String, dynamic>>().toList()
              : [],
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : 'Search failed.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await AuthScope.of(context).api.get('/conversations');
      final d = r['data'];
      final v = d is Map ? d['items'] : null;
      if (mounted)
        setState(() {
          _items = v is List
              ? v.whereType<Map<String, dynamic>>().toList()
              : [];
          _error = null;
        });
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Unable to load conversations.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> conversation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ConversationScreen(conversation: conversation),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _start(Map<String, dynamic> user) async {
    try {
      final r = await AuthScope.of(
        context,
      ).api.post('/conversations', body: {'userId': user['_id']});
      final d = r['data'];
      final c = d is Map ? d['item'] : null;
      if (c is Map<String, dynamic>) {
        _search.clear();
        setState(() => _matches = []);
        await _open(c);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Unable to open conversation.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Messages'),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            onChanged: _find,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: AuthScope.of(context).user?.role == UserRole.startup
                  ? 'Search investors'
                  : 'Search startups',
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        if (_matches.isNotEmpty)
          ..._matches.map(
            (u) => ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(u['name']?.toString() ?? 'Member'),
              subtitle: Text(
                (u['profile'] is Map
                        ? (u['profile'] as Map)['industry'] ?? ''
                        : '')
                    .toString(),
              ),
              trailing: const Icon(Icons.chat_outlined),
              onTap: () => _start(u),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _items.isEmpty
              ? const _Empty(
                  title: 'No conversations yet',
                  subtitle:
                      'Search for a member above to start a conversation.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: _items.map((c) {
                      final people = c['participants'] is List
                          ? (c['participants'] as List)
                                .whereType<Map<String, dynamic>>()
                                .toList()
                          : <Map<String, dynamic>>[];
                      final myId = AuthScope.of(context).user?.id;
                      final others = people
                          .where((p) => p['_id'] != myId && p['id'] != myId)
                          .toList();
                      final other = others.isEmpty ? null : others.first;
                      final message = c['lastMessage'];
                      final unread = c['unreadCount'] ?? 0;
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(
                            other?['name']?.toString() ?? 'Conversation',
                          ),
                          subtitle: Text(
                            message is Map
                                ? message['body']?.toString() ?? ''
                                : 'Start a conversation',
                          ),
                          trailing: unread is num && unread > 0
                              ? CircleAvatar(
                                  radius: 13,
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                )
                              : null,
                          onTap: () => _open(c),
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    ),
  );
}

class _ConversationScreen extends StatefulWidget {
  const _ConversationScreen({required this.conversation});
  final Map<String, dynamic> conversation;
  @override
  State<_ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<_ConversationScreen> {
  final _text = TextEditingController();
  bool _loading = true, _sending = false, _fetching = false;
  String? _error;
  List<Map<String, dynamic>> _messages = [];
  Timer? _poll;
  String get _id => widget.conversation['_id'].toString();
  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final r = await AuthScope.of(
        context,
      ).api.get('/conversations/$_id/messages');
      final d = r['data'];
      final v = d is Map ? d['items'] : null;
      if (mounted)
        setState(() {
          _messages = v is List
              ? v.whereType<Map<String, dynamic>>().toList()
              : [];
          _error = null;
        });
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Unable to load messages.',
        );
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await AuthScope.of(
        context,
      ).api.post('/conversations/$_id/messages', body: {'body': body});
      _text.clear();
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Unable to send message.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Conversation'),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    body: Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _messages.isEmpty
              ? const _Empty(
                  title: 'No messages yet',
                  subtitle: 'Send a message to start this conversation.',
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: _messages.map((m) {
                    final sender = m['sender'];
                    final name = sender is Map
                        ? sender['name']?.toString() ?? 'Member'
                        : 'Member';
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(m['body']?.toString() ?? ''),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await AuthScope.of(context).api.get('/notifications');
      final d = r['data'];
      final v = d is Map ? d['items'] : null;
      if (mounted)
        setState(
          () => _items = v is List
              ? v.whereType<Map<String, dynamic>>().toList()
              : [],
        );
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Unable to load notifications.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _read(String id) async {
    try {
      await AuthScope.of(context).api.put('/notifications/$id/read');
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Unable to update notification.',
            ),
          ),
        );
    }
  }

  Future<void> _readAll() async {
    try {
      await AuthScope.of(context).api.put('/notifications/read-all');
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Unable to update notifications.',
            ),
          ),
        );
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    if (n['_id'] != null && n['readAt'] == null)
      await _read(n['_id'].toString());
    final data = n['data'];
    final id = data is Map ? data['conversationId']?.toString() : null;
    if (id != null && mounted) {
      final item = {'_id': id};
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ConversationScreen(conversation: item),
        ),
      );
    } else if (n['type'] == 'INVESTMENT_REQUEST' && mounted) {
      await Navigator.pushNamed(context, AppRoutes.requests);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        IconButton(
          onPressed: _items.any((i) => i['readAt'] == null) ? _readAll : null,
          tooltip: 'Mark all read',
          icon: const Icon(Icons.done_all),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _ErrorState(message: _error!, onRetry: _load)
        : _items.isEmpty
        ? const _Empty(
            title: 'You are all caught up',
            subtitle: 'New activity and investment updates will appear here.',
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              children: _items.map((n) {
                final unread = n['readAt'] == null;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      unread
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                    ),
                    title: Text(n['title']?.toString() ?? 'Notification'),
                    subtitle: Text(
                      '${n['body'] ?? ''}\n${n['createdAt'] ?? ''}',
                    ),
                    isThreeLine: true,
                    onTap: () => _open(n),
                    trailing: unread
                        ? IconButton(
                            tooltip: 'Mark read',
                            icon: const Icon(Icons.done),
                            onPressed: () => _read(n['_id'].toString()),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
  );
}

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await AuthScope.of(context).api.get('/admin/users');
      final data = result['data'];
      final raw = data is Map ? data['items'] : null;
      if (mounted)
        setState(
          () => _users = raw is List
              ? raw.whereType<Map<String, dynamic>>().toList()
              : [],
        );
    } catch (e) {
      if (mounted)
        setState(
          () =>
              _error = e is ApiException ? e.message : 'Unable to load users.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AuthScope.of(context).user?.role != UserRole.admin)
      return const Scaffold(
        body: _Empty(
          title: 'Access denied',
          subtitle: 'Administrator access is required.',
        ),
      );
    return Scaffold(
      appBar: AppBar(
        title: const Text('User management'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : _users.isEmpty
          ? const _Empty(
              title: 'No users found',
              subtitle: 'Registered accounts will appear here.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: _users
                    .map(
                      (u) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(u['name']?.toString() ?? 'Member'),
                          subtitle: Text(
                            '${u['email'] ?? ''} · ${u['role'] ?? ''}',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _location = TextEditingController(),
      _industry = TextEditingController(),
      _stage = TextEditingController(),
      _description = TextEditingController(),
      _website = TextEditingController(),
      _fundingRequired = TextEditingController(),
      _fundingRaised = TextEditingController(),
      _investmentMin = TextEditingController(),
      _investmentMax = TextEditingController();
  final _deckTitle = TextEditingController(),
      _deckSummary = TextEditingController(),
      _deckDescription = TextEditingController();
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _pitch;
  bool _deckBusy = false;
  bool _loading = true, _saving = false, _editing = false;
  String? _loadError;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _location,
      _industry,
      _stage,
      _description,
      _website,
      _fundingRequired,
      _fundingRaised,
      _investmentMin,
      _investmentMax,
      _deckTitle,
      _deckSummary,
      _deckDescription,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populate(Map<String, dynamic>? p) {
    _name.text =
        p?['name']?.toString() ?? AuthScope.of(context).user?.name ?? '';
    _location.text = p?['location']?.toString() ?? '';
    _industry.text = p?['industry']?.toString() ?? '';
    _stage.text = p?['businessStage']?.toString() ?? '';
    _description.text = p?['description']?.toString() ?? '';
    _website.text = p?['website']?.toString() ?? '';
    _fundingRequired.text = p?['fundingRequired']?.toString() ?? '';
    _fundingRaised.text = p?['fundingRaised']?.toString() ?? '';
    _investmentMin.text = p?['investmentRangeMin']?.toString() ?? '';
    _investmentMax.text = p?['investmentRangeMax']?.toString() ?? '';
    final pitch = p?['pitch'];
    _pitch = pitch is Map<String, dynamic> ? pitch : null;
    _deckTitle.text = _pitch?['title']?.toString() ?? '';
    _deckSummary.text = _pitch?['summary']?.toString() ?? '';
    _deckDescription.text = _pitch?['description']?.toString() ?? '';
  }

  Future<void> _load() async {
    try {
      final result = await AuthScope.of(context).api.get('/profiles/me');
      final data = result['data'] as Map<String, dynamic>?;
      if (mounted)
        setState(() {
          final p = data?['profile'] as Map<String, dynamic>?;
          _profile = p;
          _populate(p);
          _loadError = null;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loadError = e is ApiException
              ? e.message
              : 'Unable to load profile.';
          _loading = false;
          _populate(null);
        });
    }
  }

  String? _number(String? value) =>
      value == null ||
          value.trim().isEmpty ||
          ((double.tryParse(value.trim()) ?? -1) >= 0)
      ? null
      : 'Enter a valid non-negative number.';

  String? _websiteValidator(String? value) {
    final website = value?.trim() ?? '';
    if (website.isEmpty) return null;
    final uri = Uri.tryParse(website);
    if (uri == null ||
        !const ['http', 'https'].contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      return 'Enter a website starting with https:// or http://.';
    }
    return null;
  }

  String? _profileNameValidator(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter a profile name.';
    if (name.length > 100) return 'Name must be 100 characters or fewer.';
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (AuthScope.of(context).user?.role == UserRole.investor &&
        _investmentMin.text.trim().isNotEmpty &&
        _investmentMax.text.trim().isNotEmpty &&
        double.parse(_investmentMin.text.trim()) >
            double.parse(_investmentMax.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The minimum investment must not exceed the maximum.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    double? number(TextEditingController c) =>
        c.text.trim().isEmpty ? null : double.parse(c.text.trim());
    try {
      final role = AuthScope.of(context).user?.role;
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'location': _location.text.trim(),
        'industry': _industry.text.trim(),
        'description': _description.text.trim(),
        'website': _website.text.trim(),
      };
      if (role == UserRole.startup) {
        body.addAll({
          'businessStage': _stage.text.trim(),
          'fundingRequired': number(_fundingRequired),
          'fundingRaised': number(_fundingRaised),
        });
      } else if (role == UserRole.investor) {
        body.addAll({
          'investmentRangeMin': number(_investmentMin),
          'investmentRangeMax': number(_investmentMax),
        });
      }
      final result = await AuthScope.of(
        context,
      ).api.put('/profiles/me', body: body);
      final data = result['data'];
      final savedProfile =
          data is Map && data['profile'] is Map<String, dynamic>
          ? data['profile'] as Map<String, dynamic>
          : null;
      if (mounted) {
        setState(() {
          _profile = savedProfile ?? {...?_profile, ...body};
          _populate(_profile);
          _editing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Unable to save profile.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelProfileEdit() {
    _populate(_profile);
    setState(() => _editing = false);
  }

  Widget _profileDetails({required bool isStartup, required bool isInvestor}) {
    final details = <(String, String)>[
      (
        isStartup
            ? 'Startup name'
            : isInvestor
            ? 'Investor / fund name'
            : 'Profile name',
        _name.text,
      ),
      ('Location', _location.text),
      ('Industry', _industry.text),
      if (isStartup) ('Business stage', _stage.text),
      (
        isStartup
            ? 'About the startup'
            : isInvestor
            ? 'Investment focus'
            : 'Description',
        _description.text,
      ),
      ('Website', _website.text),
      if (isStartup) ('Funding required', _fundingRequired.text),
      if (isStartup) ('Funding raised', _fundingRaised.text),
      if (!isStartup) ('Investment range minimum', _investmentMin.text),
      if (!isStartup) ('Investment range maximum', _investmentMax.text),
    ];
    final populated = details.where((detail) => detail.$2.trim().isNotEmpty);
    if (populated.isEmpty) {
      return const _Empty(
        title: 'Profile details are not set up yet',
        subtitle: 'Choose Edit Profile to add information for other members.',
      );
    }
    return Card(
      child: Column(
        children: populated
            .map(
              (detail) => ListTile(
                title: Text(detail.$1),
                subtitle: Text(detail.$2),
                leading: const Icon(Icons.account_circle_outlined),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _uploadDeck() async {
    FilePickerResult? selected;
    try {
      selected = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the PDF picker.')),
        );
      }
      return;
    }
    if (!mounted) return;
    if (selected == null) return;
    final file = selected.files.single;
    final bytes = file.bytes;
    if (bytes == null ||
        bytes.length > 10 * 1024 * 1024 ||
        bytes.length < 5 ||
        String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a valid PDF no larger than 10 MB.'),
          ),
        );
      return;
    }
    if (_deckTitle.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a pitch deck title first.')),
      );
      return;
    }
    setState(() => _deckBusy = true);
    try {
      final q = Uri(
        queryParameters: {
          'title': _deckTitle.text.trim(),
          'summary': _deckSummary.text.trim(),
          'description': _deckDescription.text.trim(),
        },
      ).query;
      final result = await AuthScope.of(
        context,
      ).api.putBytes('/profiles/me/pitch-deck?$q', bytes);
      final d = result['data'];
      if (mounted) {
        setState(() {
          _pitch = d is Map && d['pitch'] is Map<String, dynamic>
              ? d['pitch'] as Map<String, dynamic>
              : null;
          if (_profile != null) {
            _profile = {..._profile!, 'pitch': _pitch};
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pitch deck uploaded.')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Pitch deck upload failed.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _deckBusy = false);
    }
  }

  Future<void> _downloadDeck() async {
    final api = AuthScope.of(context).api;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final profileResult = await api.get('/profiles/me');
      final d = profileResult['data'];
      final p = d is Map ? d['profile'] : null;
      final id = p is Map ? p['_id']?.toString() : null;
      if (id == null) return;
      final bytes = await api.getBytes('/profiles/$id/pitch-deck');
      await FilePicker.platform.saveFile(
        fileName: _pitch?['filename']?.toString() ?? 'pitch-deck.pdf',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
    } catch (e) {
      if (mounted)
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Unable to download pitch deck.',
            ),
          ),
        );
    }
  }

  Future<void> _deleteDeck() async {
    final api = AuthScope.of(context).api;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete pitch deck?'),
        content: const Text('This removes your uploaded PDF.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final profile = await api.get('/profiles/me');
      final d = profile['data'];
      final p = d is Map ? d['profile'] : null;
      final id = p is Map ? p['_id']?.toString() : null;
      if (id != null) {
        await api.delete('/profiles/me/pitch-deck');
      }
      if (mounted) {
        setState(() {
          _pitch = null;
          if (_profile != null) _profile = {..._profile!, 'pitch': null};
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Pitch deck removed.')),
        );
      }
    } catch (e) {
      if (mounted)
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Unable to delete pitch deck.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).user;
    final isStartup = user?.role == UserRole.startup;
    final isInvestor = user?.role == UserRole.investor;
    final canEdit = user?.role != UserRole.admin;
    final nameLabel = isStartup
        ? 'Startup name'
        : isInvestor
        ? 'Investor / fund name'
        : 'Profile name';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (canEdit && !_editing)
            TextButton.icon(
              onPressed: _loading || _saving
                  ? null
                  : () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Profile'),
            ),
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh profile',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const CircleAvatar(
                  radius: 48,
                  child: Icon(Icons.person, size: 48),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    _profile?['name']?.toString() ?? user?.name ?? '',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    user?.role.label ?? '',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 24),
                if (_loadError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Could not refresh saved profile: $_loadError',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (!_editing)
                  _profileDetails(isStartup: isStartup, isInvestor: isInvestor)
                else
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _field(
                          _name,
                          nameLabel,
                          validator: _profileNameValidator,
                        ),
                        _field(_location, 'Location'),
                        _field(_industry, 'Industry'),
                        if (isStartup) _field(_stage, 'Business stage'),
                        _field(
                          _description,
                          isStartup ? 'About the startup' : 'Investment focus',
                          lines: 3,
                        ),
                        _field(
                          _website,
                          'Website',
                          keyboard: TextInputType.url,
                          validator: _websiteValidator,
                        ),
                        if (isStartup) ...[
                          _field(
                            _fundingRequired,
                            'Funding required',
                            keyboard: TextInputType.number,
                            validator: _number,
                          ),
                          _field(
                            _fundingRaised,
                            'Funding raised',
                            keyboard: TextInputType.number,
                            validator: _number,
                          ),
                        ],
                        if (isInvestor) ...[
                          _field(
                            _investmentMin,
                            'Investment range minimum',
                            keyboard: TextInputType.number,
                            validator: _number,
                          ),
                          _field(
                            _investmentMax,
                            'Investment range maximum',
                            keyboard: TextInputType.number,
                            validator: _number,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving ? null : _cancelProfileEdit,
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _saving ? null : _save,
                                child: _saving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save Changes'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (isStartup) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Pitch deck PDF',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_pitch != null)
                    ListTile(
                      leading: const Icon(Icons.picture_as_pdf),
                      title: Text(_pitch?['title']?.toString() ?? 'Pitch deck'),
                      subtitle: Text(
                        _pitch?['summary']?.toString() ?? 'PDF available',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'download') _downloadDeck();
                          if (v == 'delete') _deleteDeck();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'download',
                            child: Text('Download'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  _field(_deckTitle, 'Deck title'),
                  _field(_deckSummary, 'Idea summary', lines: 2),
                  _field(_deckDescription, 'Deck description', lines: 3),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _deckBusy ? null : _uploadDeck,
                      icon: _deckBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(
                        _pitch == null
                            ? 'Select and upload PDF'
                            : 'Replace pitch deck',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _Item(
                  Icons.bookmark_outline,
                  'Saved profiles',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DiscoveryScreen(initialSaved: true),
                    ),
                  ),
                ),
                _Item(Icons.logout, 'Logout', () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Log Out'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;
                  await AuthScope.of(context).logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (_) => false,
                    );
                  }
                }),
              ],
            ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    TextInputType? keyboard,
    int lines = 1,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
      maxLines: lines,
      validator:
          validator ?? (required ? (v) => Validators.required(v, label) : null),
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.title, this.onTap);
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 58, color: Colors.grey),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    ),
  );
}
