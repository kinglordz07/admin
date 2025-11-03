import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AdminPanelScreen extends StatefulWidget {
  final VoidCallback onLogout; // DAGDAG: Add this parameter
  
  const AdminPanelScreen({super.key, required this.onLogout}); // DAGDAG: Update constructor

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isMobile = false;
  String? _currentUserId;

  List<Map<String, dynamic>> activeUsers = [];
  List<Map<String, dynamic>> pendingUsers = [];
  List<Map<String, dynamic>> filteredActiveUsers = [];
  List<Map<String, dynamic>> activities = [];
  List<Map<String, dynamic>> filteredActivities = [];
  List<Map<String, dynamic>> resources = [];
  List<Map<String, dynamic>> videos = [];
  List<Map<String, dynamic>> articles = [];
  List<Map<String, dynamic>> quizzes = [];
  List<Map<String, dynamic>> rooms = [];
  List<Map<String, dynamic>> sessions = [];

  String searchQueryUsers = '';
  String searchQueryActivities = '';
  String searchQueryResources = '';
  String searchQueryVideos = '';
  String searchQueryArticles = '';
  String searchQueryQuizzes = '';
  String searchQueryRooms = '';
  String searchQuerySessions = '';
  
  bool isDarkMode = false;
  int userRoleIndex = 0;

  String? activityFilterUserId;
  String? activityFilterUsername;

  // Statistics
  Map<String, dynamic> stats = {
    'totalUsers': 0,
    'totalMentors': 0,
    'totalStudents': 0,
    'pendingApprovals': 0,
    'totalActivities': 0,
    'totalResources': 0,
    'totalVideos': 0,
    'totalArticles': 0,
    'totalQuizzes': 0,
    'totalRooms': 0,
    'activeSessions': 0,
    'todayActivities': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
    _loadCurrentUser();
    _loadThemePref();
    _fetchAllData();
    _subscribeToChanges();
  }

  // DAGDAG: Logout function
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout(); // Call the logout function
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- LOAD CURRENT USER ----------------
  Future<void> _loadCurrentUser() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        setState(() {
          _currentUserId = user.id;
        });
      }
    } catch (e) {
      debugPrint('❌ loadCurrentUser error: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkScreenSize();
  }

  void _checkScreenSize() {
    final mediaQuery = MediaQuery.of(context);
    setState(() {
      _isMobile = mediaQuery.size.width < 768;
    });
  }

  // ---------------- THEME ----------------
  Future<void> _loadThemePref() async {
    final sp = await SharedPreferences.getInstance();
    setState(() => isDarkMode = sp.getBool('admin_isDark') ?? false);
  }

  Future<void> _toggleTheme() async {
    final sp = await SharedPreferences.getInstance();
    setState(() => isDarkMode = !isDarkMode);
    await sp.setBool('admin_isDark', isDarkMode);
  }

  // ---------------- FETCH ALL DATA ----------------
  Future<void> _fetchAllData() async {
    await Future.wait([
      _fetchUsers(),
      _loadActivities(),
      _fetchResources(),
      _fetchVideos(),
      _fetchArticles(),
      _fetchQuizzes(),
      _fetchRooms(),
      _fetchSessions(),
      _fetchStatistics(),
    ]);
  }

  // ---------------- STATISTICS ----------------
  Future<void> _fetchStatistics() async {
    try {
      // User statistics
      final usersRes = await supabase
          .from('profiles_new')
          .select('role, is_approved, created_at');
      
      final users = List<Map<String, dynamic>>.from(usersRes as List);
      
      // Activities count
      final activitiesRes = await supabase
          .from('activities')
          .select('created_at');
      
      final allActivities = List<Map<String, dynamic>>.from(activitiesRes as List);
      
      // Today's activities
      final today = DateTime.now();
      final todayActivities = allActivities.where((a) {
        final createdAt = DateTime.parse(a['created_at']).toLocal();
        return createdAt.year == today.year &&
               createdAt.month == today.month &&
               createdAt.day == today.day;
      }).length;

      // Resources count
      final resourcesRes = await supabase
          .from('resources')
          .select('id')
          .eq('is_removed', false);
      
      // Videos count
      final videosRes = await supabase
          .from('video_urls')
          .select('id')
          .eq('is_removed', false);
      
      // Articles count
      final articlesRes = await supabase.from('articles').select('id');
      
      // Quizzes count
      final quizzesRes = await supabase
          .from('quizzes')
          .select('id')
          .eq('is_active', true);
      
      // Rooms count
      final roomsRes = await supabase.from('rooms').select('id');
      
      // Active sessions
      final sessionsRes = await supabase
          .from('live_sessions')
          .select('id')
          .eq('is_live', true);

      if (!mounted) return;

      setState(() {
        stats = {
          'totalUsers': users.length,
          'totalMentors': users.where((u) => u['role'] == 'mentor').length,
          'totalStudents': users.where((u) => u['role'] == 'student').length,
          'pendingApprovals': users.where((u) => 
            u['is_approved'] == false || u['is_approved'] == 0 || 
            u['is_approved'] == 'f' || u['is_approved'] == 'false'
          ).length,
          'totalActivities': allActivities.length,
          'totalResources': (resourcesRes as List).length,
          'totalVideos': (videosRes as List).length,
          'totalArticles': (articlesRes as List).length,
          'totalQuizzes': (quizzesRes as List).length,
          'totalRooms': (roomsRes as List).length,
          'activeSessions': (sessionsRes as List).length,
          'todayActivities': todayActivities,
        };
      });
    } catch (e, st) {
      debugPrint('❌ fetchStatistics error: $e\n$st');
    }
  }

  // ---------------- FETCH USERS ----------------
  Future<void> _fetchUsers() async {
    try {
      final res = await supabase
          .from('profiles_new')
          .select('id, username, role, is_approved, created_at, online_status')
          .order('created_at', ascending: false);
      final data = List<Map<String, dynamic>>.from(res as List);
      if (!mounted) return;

      setState(() {
        activeUsers = data.where((u) {
          final approved = u['is_approved'];
          return approved == true || approved == 1 || approved == 't' || approved == 'true';
        }).toList();

        pendingUsers = data.where((u) {
          final approved = u['is_approved'];
          return approved == false || approved == 0 || approved == 'f' || approved == 'false';
        }).toList();

        _applyUserFilter();
      });
    } catch (e, st) {
      debugPrint('❌ fetchUsers error: $e\n$st');
    }
  }

  void _applyUserFilter() {
    final query = searchQueryUsers.toLowerCase();
    final role = userRoleIndex == 0 ? 'student' : 'mentor';

    filteredActiveUsers = activeUsers.where((u) {
      final matchRole = (u['role'] ?? '').toString().toLowerCase() == role;
      final matchName = (u['username'] ?? '').toString().toLowerCase().contains(query);
      return matchRole && matchName;
    }).toList();
  }

  // ---------------- ACTIVITIES ----------------
  Future<void> _loadActivities({String? userId}) async {
    try {
      var query = supabase.from('activities').select('*');
      final data = userId != null
          ? await query.eq('user_id', userId).order('created_at', ascending: false)
          : await query.order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(data as List);
      if (!mounted) return;

      setState(() {
        activities = list;
        filteredActivities = List.from(activities);
      });
    } catch (e, st) {
      debugPrint('❌ loadActivities error: $e\n$st');
    }
  }

  void _filterActivities(String query) {
    final q = query.toLowerCase();
    setState(() {
      searchQueryActivities = query;
      filteredActivities = activities.where((a) {
        return (a['username'] ?? '').toString().toLowerCase().contains(q) ||
            (a['action'] ?? '').toString().toLowerCase().contains(q) ||
            (a['details'] ?? '').toString().toLowerCase().contains(q) ||
            (a['table_name'] ?? '').toString().toLowerCase().contains(q);
      }).toList();
    });
  }

  // ---------------- RESOURCES MANAGEMENT ----------------
  Future<void> _fetchResources() async {
  try {
    final res = await supabase
        .from('resources')
        .select('*')
        .eq('is_removed', false)  // Only get non-removed resources
        .order('uploaded_at', ascending: false);
    
    final data = List<Map<String, dynamic>>.from(res as List);
    if (!mounted) return;

    setState(() {
      resources = data;
    });
    
    debugPrint('✅ Fetched ${resources.length} active resources');
  } catch (e, st) {
    debugPrint('❌ fetchResources error: $e\n$st');
  }
}

  Future<void> _deleteResource(Map<String, dynamic> resource) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Resource'),
      content: Text('Delete "${resource['title']}"? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    final resourceId = resource['id'];
    debugPrint('🔄 Deleting resource ID: $resourceId');
    
    // Ensure we have current user
    if (_currentUserId == null) {
      await _loadCurrentUser();
    }

    // Perform soft delete
    await supabase
        .from('resources')
        .update({
          'is_removed': true,
          'removed_at': DateTime.now().toIso8601String(),
          'removed_by': _currentUserId,
        })
        .eq('id', resourceId);

    debugPrint('✅ Resource soft delete successful');

    await _logActivity(
      userId: _currentUserId ?? 'admin',
      username: 'Admin',
      role: 'admin',
      action: 'Deleted Resource',
      details: 'Deleted resource: ${resource['title']}',
    );

    // Refresh data
    await _fetchResources();
    await _fetchStatistics();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Resource "${resource['title']}" deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e, st) {
    debugPrint('❌ deleteResource error: $e');
    debugPrint('Stack trace: $st');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to delete resource: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  // ---------------- VIDEOS MANAGEMENT ----------------
  Future<void> _fetchVideos() async {
  try {
    final res = await supabase
        .from('video_urls')
        .select('*')
        .eq('is_removed', false)  // Only get non-removed videos
        .order('created_at', ascending: false);
    
    final data = List<Map<String, dynamic>>.from(res as List);
    if (!mounted) return;

    setState(() {
      videos = data;
    });
    
    debugPrint('✅ Fetched ${videos.length} active videos');
  } catch (e, st) {
    debugPrint('❌ fetchVideos error: $e\n$st');
  }
}

  Future<void> _deleteVideo(Map<String, dynamic> video) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Video'),
      content: Text('Delete "${video['title']}"? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    final videoId = video['id'];
    debugPrint('🔄 Deleting video ID: $videoId');

    // Perform soft delete for videos
    await supabase
        .from('video_urls')
        .update({
          'is_removed': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', videoId);

    debugPrint('✅ Video soft delete successful');

    await _logActivity(
      userId: _currentUserId ?? 'admin',
      username: 'Admin',
      role: 'admin',
      action: 'Deleted Video',
      details: 'Deleted video: ${video['title']}',
    );

    // Refresh data
    await _fetchVideos();
    await _fetchStatistics();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Video "${video['title']}" deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e, st) {
    debugPrint('❌ deleteVideo error: $e');
    debugPrint('Stack trace: $st');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to delete video: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  // ---------------- ARTICLES MANAGEMENT ----------------
  Future<void> _fetchArticles() async {
  try {
    final res = await supabase
        .from('articles')
        .select('*')
        .order('created_at', ascending: false);
    
    final data = List<Map<String, dynamic>>.from(res as List);
    if (!mounted) return;

    setState(() {
      articles = data;
    });
    
    debugPrint('✅ Fetched ${articles.length} articles');
  } catch (e, st) {
    debugPrint('❌ fetchArticles error: $e\n$st');
  }
}

  Future<void> _deleteArticle(Map<String, dynamic> article) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Article'),
      content: Text('Delete "${article['title']}"? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    final articleId = article['id'];
    debugPrint('🔄 Deleting article ID: $articleId');

    // Articles table doesn't have is_removed, so use hard delete
    await supabase
        .from('articles')
        .delete()
        .eq('id', articleId);

    debugPrint('✅ Article hard delete successful');

    await _logActivity(
      userId: _currentUserId ?? 'admin',
      username: 'Admin',
      role: 'admin',
      action: 'Deleted Article',
      details: 'Deleted article: ${article['title']}',
    );

    // Refresh data
    await _fetchArticles();
    await _fetchStatistics();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Article "${article['title']}" deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e, st) {
    debugPrint('❌ deleteArticle error: $e');
    debugPrint('Stack trace: $st');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to delete article: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  // ---------------- QUIZZES MANAGEMENT ----------------
  Future<void> _fetchQuizzes() async {
    try {
      final res = await supabase
          .from('quizzes')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false);
      final data = List<Map<String, dynamic>>.from(res as List);
      if (!mounted) return;

      setState(() {
        quizzes = data;
      });
    } catch (e, st) {
      debugPrint('❌ fetchQuizzes error: $e\n$st');
    }
  }

  Future<void> _toggleQuizStatus(Map<String, dynamic> quiz) async {
    try {
      await supabase
          .from('quizzes')
          .update({'is_active': !(quiz['is_active'] ?? true)})
          .eq('id', quiz['id']);

      await _logActivity(
        userId: quiz['user_id'] ?? '',
        username: 'Admin',
        role: 'admin',
        action: 'Updated Quiz',
        details: '${quiz['is_active'] ? 'Deactivated' : 'Activated'} quiz: ${_truncateText(quiz['question']?.toString() ?? '', 30)}',
      );

      await _fetchQuizzes();
    } catch (e) {
      debugPrint('❌ toggleQuizStatus error: $e');
    }
  }

  // ---------------- ROOMS MANAGEMENT ----------------
  Future<void> _fetchRooms() async {
    try {
      final res = await supabase
          .from('rooms')
          .select('*')
          .order('created_at', ascending: false);
      final data = List<Map<String, dynamic>>.from(res as List);
      if (!mounted) return;

      setState(() {
        rooms = data;
      });
    } catch (e, st) {
      debugPrint('❌ fetchRooms error: $e\n$st');
    }
  }

  Future<void> _deleteRoom(Map<String, dynamic> room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text('Delete "${room['name']}"? This will also remove all messages and files in this room.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('rooms')
          .delete()
          .eq('id', room['id']);

      await _logActivity(
        userId: room['creator_id'] ?? '',
        username: 'Admin',
        role: 'admin',
        action: 'Deleted Room',
        details: 'Deleted room: ${room['name']}',
      );

      await _fetchRooms();
      await _fetchStatistics();
    } catch (e) {
      debugPrint('❌ deleteRoom error: $e');
    }
  }

  // ---------------- SESSIONS MANAGEMENT ----------------
  Future<void> _fetchSessions() async {
    try {
      final res = await supabase
          .from('live_sessions')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);
      final data = List<Map<String, dynamic>>.from(res as List);
      if (!mounted) return;

      setState(() {
        sessions = data;
      });
    } catch (e, st) {
      debugPrint('❌ fetchSessions error: $e\n$st');
    }
  }

  // ---------------- SUBSCRIPTIONS ----------------
  void _subscribeToChanges() {
    // Activities subscription
    supabase
        .channel('public:activities')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'activities',
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (mounted) {
              setState(() {
                final idx = activities.indexWhere((a) => a['id'] == newRecord['id']);
                if (idx != -1) {
                  activities[idx] = newRecord;
                } else {
                  activities.insert(0, newRecord);
                }
                _filterActivities(searchQueryActivities);
              });
              _fetchStatistics();
            }
          },
        )
        .subscribe();

    // Users subscription
    supabase
        .channel('public:profiles_new')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles_new',
          callback: (payload) {
            if (mounted) {
              _fetchUsers();
              _fetchStatistics();
            }
          },
        )
        .subscribe();
  }

  // ---------------- LOG ACTIVITY ----------------
  Future<void> _logActivity({
    required String userId,
    required String username,
    required String role,
    required String action,
    required String details,
  }) async {
    try {
      await supabase.from('activities').insert({
        'user_id': userId,
        'username': username,
        'role': role,
        'action': action,
        'details': details,
        'table_name': 'admin_panel',
      });
    } catch (e) {
      debugPrint('❌ logActivity error: $e');
    }
  }

  // ---------------- CRUD OPERATIONS ----------------
  Future<void> _addOrEditUser({Map<String, dynamic>? user}) async {
    final isEdit = user != null;
    final usernameCtrl = TextEditingController(text: user?['username'] ?? '');
    String role = user?['role'] ?? 'student';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit User' : 'Add User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: role,
              items: const [
                DropdownMenuItem(value: 'student', child: Text('Student')),
                DropdownMenuItem(value: 'mentor', child: Text('Mentor')),
              ],
              onChanged: (v) => role = v ?? 'student',
              decoration: const InputDecoration(labelText: 'Role'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final username = usernameCtrl.text.trim();
              if (username.isEmpty) return;
              Navigator.pop(ctx);

              try {
                if (isEdit) {
                  await supabase.from('profiles_new').update({
                    'username': username,
                    'role': role,
                  }).eq('id', user['id']);

                  await _logActivity(
                    userId: user['id'],
                    username: username,
                    role: role,
                    action: 'Updated',
                    details: 'Admin updated user $username',
                  );
                } else {
                  final inserted = await supabase.from('profiles_new').insert({
                    'username': username,
                    'role': role,
                    'is_approved': false,
                  }).select();

                  final newUser = (inserted as List).first as Map<String, dynamic>;
                  await _logActivity(
                    userId: newUser['id'],
                    username: username,
                    role: role,
                    action: 'Created',
                    details: 'Admin created $role $username',
                  );
                }
                await _fetchUsers();
              } catch (e) {
                debugPrint('❌ addOrEditUser error: $e');
              }
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

 Future<void> _deleteUser(Map<String, dynamic> user) async {
  final isCurrentUser = user['id'] == _currentUserId;
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isCurrentUser ? 'Delete Your Own Account' : 'Confirm Delete'),
      content: Text(
        isCurrentUser 
          ? '⚠️ WARNING: You are about to delete YOUR OWN ACCOUNT!\n\nThis will permanently delete your profile and all associated data.\n\nYou will be logged out immediately.\n\nAre you absolutely sure?'
          : 'Delete user "${user['username']}"? This will permanently remove their profile and all associated data.',
        style: TextStyle(
          color: isCurrentUser ? Colors.red : null,
          fontWeight: isCurrentUser ? FontWeight.bold : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isCurrentUser ? Colors.red : Colors.redAccent,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(isCurrentUser ? 'DELETE MY ACCOUNT' : 'Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleting user ${user['username']}...'),
          duration: Duration(seconds: 5),
        ),
      );
    }

    // USE THE DATABASE FUNCTION DIRECTLY
    final result = await supabase.rpc(
      'admin_delete_user_cascade', 
      params: {'target_user_id': user['id']}
    );
    
    debugPrint('✅ Database function result: $result');
    
    await _logActivity(
      userId: user['id'],
      username: 'Admin',
      role: 'admin',
      action: 'Deleted User',
      details: 'Deleted user: ${user['username']} - $result',
    );

    // If the deleted user is the current user, log them out
    if (isCurrentUser) {
      await supabase.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been deleted. You have been logged out.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } else {
      await _fetchUsers();
      await _loadActivities();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "${user['username']}" has been deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('❌ deleteUser error: $e');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete user: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


  Future<void> _approveUser(Map<String, dynamic> user) async {
    try {
      await supabase.from('profiles_new').update({'is_approved': true}).eq('id', user['id']);
      final updatedUser = await supabase
          .from('profiles_new')
          .select('id, username, role')
          .eq('id', user['id'])
          .maybeSingle();
      final u = updatedUser;

      if (u != null) {
        await _logActivity(
          userId: u['id'],
          username: u['username'],
          role: u['role'],
          action: 'Approved',
          details: 'Admin approved ${u['username']}',
        );
      }

      await _fetchUsers();
    } catch (e) {
      debugPrint('❌ approveUser error: $e');
    }
  }

  Future<void> _rejectUser(Map<String, dynamic> user) async {
    try {
      await supabase.from('profiles_new').delete().eq('id', user['id']);
      await _logActivity(
        userId: user['id'],
        username: user['username'],
        role: user['role'],
        action: 'Rejected',
        details: 'Admin rejected ${user['username']}',
      );
      await _fetchUsers();
    } catch (e) {
      debugPrint('❌ rejectUser error: $e');
    }
  }

  // ---------------- HELPER METHODS ----------------
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  // ---------------- RESPONSIVE UI COMPONENTS ----------------
  Widget _buildDashboardTab() {
    final crossAxisCount = _isMobile ? 2 : 4;
    final childAspectRatio = _isMobile ? 1.2 : 1.5;

    return SingleChildScrollView(
      padding: EdgeInsets.all(_isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: _isMobile ? 8 : 16,
            mainAxisSpacing: _isMobile ? 8 : 16,
            children: [
              _buildStatCard('Total Users', stats['totalUsers'], Icons.people, Colors.blue),
              _buildStatCard('Mentors', stats['totalMentors'], Icons.school, Colors.green),
              _buildStatCard('Students', stats['totalStudents'], Icons.person, Colors.orange),
              _buildStatCard('Pending', stats['pendingApprovals'], Icons.pending_actions, Colors.red),
              _buildStatCard('Activities', stats['totalActivities'], Icons.analytics, Colors.purple),
              _buildStatCard('Resources', stats['totalResources'], Icons.folder, Colors.teal),
              _buildStatCard('Videos', stats['totalVideos'], Icons.video_library, Colors.pink),
              _buildStatCard('Active Sessions', stats['activeSessions'], Icons.video_call, Colors.deepOrange),
            ],
          ),

          SizedBox(height: _isMobile ? 16 : 24),

          // Quick Actions
          Text('Quick Actions', 
            style: TextStyle(
              fontSize: _isMobile ? 18 : 20, 
              fontWeight: FontWeight.bold
            )),
          SizedBox(height: _isMobile ? 12 : 16),
          Wrap(
            spacing: _isMobile ? 8 : 12,
            runSpacing: _isMobile ? 8 : 12,
            children: [
              _buildQuickAction('Refresh All', Icons.refresh, () => _fetchAllData()),
              _buildQuickAction('View Pending', Icons.pending, () => _tabController.animateTo(1)),
              _buildQuickAction('Monitor Activities', Icons.monitor, () => _tabController.animateTo(8)),
              _buildQuickAction('Manage Resources', Icons.folder, () => _tabController.animateTo(3)),
              _buildQuickAction('Manage Rooms', Icons.meeting_room, () => _tabController.animateTo(7)),
            ],
          ),

          SizedBox(height: _isMobile ? 16 : 24),

          // Recent Activities
          Text('Recent Activities', 
            style: TextStyle(
              fontSize: _isMobile ? 18 : 20, 
              fontWeight: FontWeight.bold
            )),
          SizedBox(height: _isMobile ? 12 : 16),
          ...activities.take(5).map((activity) => Card(
            margin: EdgeInsets.only(bottom: _isMobile ? 6 : 8),
            child: ListTile(
              leading: Icon(Icons.history, size: _isMobile ? 20 : 24),
              title: Text(
                '${activity['username']} • ${activity['action']}',
                style: TextStyle(fontSize: _isMobile ? 14 : 16),
              ),
              subtitle: Text(
                activity['details'] ?? '',
                style: TextStyle(fontSize: _isMobile ? 12 : 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _formatTime(activity['created_at']),
                style: TextStyle(fontSize: _isMobile ? 10 : 12, color: Colors.grey),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(_isMobile ? 12 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: _isMobile ? 30 : 40, color: color),
            SizedBox(height: _isMobile ? 4 : 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: _isMobile ? 18 : 24, 
                fontWeight: FontWeight.bold
              ),
            ),
            SizedBox(height: _isMobile ? 2 : 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _isMobile ? 10 : 12, 
                color: Colors.grey
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(_isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: _isMobile ? 24 : 30),
            SizedBox(height: _isMobile ? 4 : 8),
            Text(
              title, 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: _isMobile ? 12 : 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(_isMobile ? 8 : 12),
          child: _isMobile 
            ? Column(
                children: [
                  ToggleButtons(
                    isSelected: [userRoleIndex == 0, userRoleIndex == 1],
                    onPressed: (i) {
                      setState(() {
                        userRoleIndex = i;
                        _applyUserFilter();
                      });
                    },
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Students')),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Mentors')),
                    ],
                  ),
                  SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search), 
                      hintText: 'Search username...',
                      isDense: true,
                    ),
                    onChanged: (q) {
                      setState(() {
                        searchQueryUsers = q;
                        _applyUserFilter();
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _addOrEditUser(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add User'),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  ToggleButtons(
                    isSelected: [userRoleIndex == 0, userRoleIndex == 1],
                    onPressed: (i) {
                      setState(() {
                        userRoleIndex = i;
                        _applyUserFilter();
                      });
                    },
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Students')),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Mentors')),
                    ],
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search), 
                        hintText: 'Search username...'
                      ),
                      onChanged: (q) {
                        setState(() {
                          searchQueryUsers = q;
                          _applyUserFilter();
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _addOrEditUser(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add User'),
                  ),
                ],
              ),
        ),
        Expanded(
          child: _isMobile 
            ? ListView.builder(
                itemCount: filteredActiveUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredActiveUsers[index];
                  final isCurrentUser = user['id'] == _currentUserId;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      title: Row(
                        children: [
                          Text(user['username'] ?? ''),
                          if (isCurrentUser) 
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Role: ${user['role'] ?? ''}'),
                          Text('Created: ${_formatDate(user['created_at'])}'),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: const ListTile(
                              leading: Icon(Icons.remove_red_eye),
                              title: Text('View Activities'),
                            ),
                            onTap: () {
                              setState(() {
                                activityFilterUserId = user['id'];
                                activityFilterUsername = user['username'];
                              });
                              _loadActivities(userId: user['id']);
                              _tabController.animateTo(8);
                            },
                          ),
                          PopupMenuItem(
                            child: const ListTile(
                              leading: Icon(Icons.edit, color: Colors.orange),
                              title: Text('Edit'),
                            ),
                            onTap: () => _addOrEditUser(user: user),
                          ),
                          PopupMenuItem(
                            child: ListTile(
                              leading: Icon(Icons.delete, 
                                color: isCurrentUser ? Colors.red : Colors.redAccent),
                              title: Text(
                                isCurrentUser ? 'Delete My Account' : 'Delete',
                                style: TextStyle(
                                  color: isCurrentUser ? Colors.red : null,
                                  fontWeight: isCurrentUser ? FontWeight.bold : null,
                                ),
                              ),
                            ),
                            onTap: () => _deleteUser(user),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 60,
                  columns: const [
                    DataColumn(label: Text('Username')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Created')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: filteredActiveUsers.map((user) {
                    final isCurrentUser = user['id'] == _currentUserId;
                    return DataRow(cells: [
                      DataCell(Row(
                        children: [
                          Text(user['username'] ?? ''),
                          if (isCurrentUser) 
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      )),
                      DataCell(Text(user['role'] ?? '')),
                      DataCell(Text(_formatDate(user['created_at']))),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_red_eye, size: 20),
                            tooltip: 'View activities',
                            onPressed: () {
                              setState(() {
                                activityFilterUserId = user['id'];
                                activityFilterUsername = user['username'];
                              });
                              _loadActivities(userId: user['id']);
                              _tabController.animateTo(8);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Colors.orange),
                            onPressed: () => _addOrEditUser(user: user),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete, 
                              size: 20, 
                              color: isCurrentUser ? Colors.red : Colors.redAccent,
                            ),
                            tooltip: isCurrentUser ? 'Delete Your Account' : 'Delete User',
                            onPressed: () => _deleteUser(user),
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildPendingTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(_isMobile ? 8.0 : 16.0),
          child: Text(
            'Pending approvals: ${pendingUsers.length}', 
            style: TextStyle(
              fontSize: _isMobile ? 16 : 18, 
              fontWeight: FontWeight.bold
            )),
        ),
        Expanded(
          child: _isMobile
            ? ListView.builder(
                itemCount: pendingUsers.length,
                itemBuilder: (context, index) {
                  final user = pendingUsers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      title: Text(user['username'] ?? ''),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Role: ${user['role'] ?? ''}'),
                          Text('Created: ${_formatDate(user['created_at'])}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _approveUser(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _rejectUser(user),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 60,
                  columns: const [
                    DataColumn(label: Text('Username')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Created')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: pendingUsers.map((user) {
                    return DataRow(cells: [
                      DataCell(Text(user['username'] ?? '')),
                      DataCell(Text(user['role'] ?? '')),
                      DataCell(Text(_formatDate(user['created_at']))),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(horizontal: _isMobile ? 8 : 16),
                            ),
                            onPressed: () => _approveUser(user),
                            child: Text('Approve', style: TextStyle(fontSize: _isMobile ? 12 : 14)),
                          ),
                          SizedBox(width: _isMobile ? 4 : 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: EdgeInsets.symmetric(horizontal: _isMobile ? 8 : 16),
                            ),
                            onPressed: () => _rejectUser(user),
                            child: Text('Reject', style: TextStyle(fontSize: _isMobile ? 12 : 14)),
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildResourcesTab() {
    return _buildResponsiveListTab(
      items: resources,
      searchQuery: searchQueryResources,
      onSearchChanged: (value) => setState(() => searchQueryResources = value),
      searchHint: 'Search resources...',
      buildItem: (resource) => ListTile(
        leading: const Icon(Icons.folder),
        title: Text(resource['title'] ?? 'Untitled'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${resource['category']}'),
            Text('Type: ${resource['resource_type']}'),
            if (resource['youtube_link'] != null) 
              Text('YouTube: ${resource['youtube_link']}'),
            Text('Uploaded: ${_formatDate(resource['uploaded_at'])}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteResource(resource),
        ),
      ),
    );
  }

  Widget _buildVideosTab() {
    return _buildResponsiveListTab(
      items: videos,
      searchQuery: searchQueryVideos,
      onSearchChanged: (value) => setState(() => searchQueryVideos = value),
      searchHint: 'Search videos...',
      buildItem: (video) => ListTile(
        leading: const Icon(Icons.video_library),
        title: Text(video['title'] ?? 'Untitled'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${video['category']}'),
            if (video['duration'] != null) Text('Duration: ${video['duration']}'),
            Text('Created: ${_formatDate(video['created_at'])}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteVideo(video),
        ),
      ),
    );
  }

  Widget _buildArticlesTab() {
    return _buildResponsiveListTab(
      items: articles,
      searchQuery: searchQueryArticles,
      onSearchChanged: (value) => setState(() => searchQueryArticles = value),
      searchHint: 'Search articles...',
      buildItem: (article) => ListTile(
        leading: const Icon(Icons.article),
        title: Text(article['title'] ?? 'Untitled'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Has Attachment: ${article['has_attachment'] ?? false}'),
            if (article['youtube_link'] != null) 
              Text('YouTube: ${article['youtube_link']}'),
            Text('Created: ${_formatDate(article['created_at'])}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteArticle(article),
        ),
      ),
    );
  }

  Widget _buildQuizzesTab() {
    return _buildResponsiveListTab(
      items: quizzes,
      searchQuery: searchQueryQuizzes,
      onSearchChanged: (value) => setState(() => searchQueryQuizzes = value),
      searchHint: 'Search quizzes...',
      buildItem: (quiz) => ListTile(
        leading: const Icon(Icons.quiz),
        title: Text(
          _truncateText(quiz['question']?.toString() ?? 'Untitled', 50),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${quiz['category']}'),
            Text('Difficulty: ${quiz['difficulty']}'),
            Text('Created: ${_formatDate(quiz['created_at'])}'),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            quiz['is_active'] == true ? Icons.toggle_on : Icons.toggle_off,
            color: quiz['is_active'] == true ? Colors.green : Colors.grey,
            size: 30,
          ),
          onPressed: () => _toggleQuizStatus(quiz),
        ),
      ),
    );
  }

  Widget _buildRoomsTab() {
    return _buildResponsiveListTab(
      items: rooms,
      searchQuery: searchQueryRooms,
      onSearchChanged: (value) => setState(() => searchQueryRooms = value),
      searchHint: 'Search rooms...',
      buildItem: (room) => ListTile(
        leading: const Icon(Icons.meeting_room),
        title: Text(room['name'] ?? 'Untitled'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description: ${room['description'] ?? 'No description'}'),
            Text('Public: ${room['is_public'] ?? false}'),
            Text('Max Participants: ${room['max_participants'] ?? 10}'),
            Text('Active Session: ${room['has_active_session'] ?? false}'),
            Text('Created: ${_formatDate(room['created_at'])}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteRoom(room),
        ),
      ),
    );
  }

  Widget _buildResponsiveListTab({
    required List<Map<String, dynamic>> items,
    required String searchQuery,
    required ValueChanged<String> onSearchChanged,
    required String searchHint,
    required Widget Function(Map<String, dynamic>) buildItem,
  }) {
    final filteredItems = searchQuery.isEmpty
        ? items
        : items.where((item) {
            final title = item['title']?.toString().toLowerCase() ?? '';
            final category = item['category']?.toString().toLowerCase() ?? '';
            final name = item['name']?.toString().toLowerCase() ?? '';
            final question = item['question']?.toString().toLowerCase() ?? '';
            return title.contains(searchQuery.toLowerCase()) ||
                category.contains(searchQuery.toLowerCase()) ||
                name.contains(searchQuery.toLowerCase()) ||
                question.contains(searchQuery.toLowerCase());
          }).toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(_isMobile ? 8 : 12),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: searchHint,
              isDense: _isMobile,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        Expanded(
          child: filteredItems.isEmpty
              ? const Center(child: Text('No items found.'))
              : ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) => Card(
                    margin: EdgeInsets.symmetric(
                      horizontal: _isMobile ? 8 : 12,
                      vertical: _isMobile ? 2 : 4,
                    ),
                    child: buildItem(filteredItems[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildActivitiesTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(_isMobile ? 8 : 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search activities...',
                    isDense: _isMobile,
                  ),
                  onChanged: _filterActivities,
                ),
              ),
              if (!_isMobile) const SizedBox(width: 8),
              if (!_isMobile && activityFilterUsername != null)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      activityFilterUserId = null;
                      activityFilterUsername = null;
                    });
                    _loadActivities();
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Show All'),
                ),
            ],
          ),
        ),
        if (_isMobile && activityFilterUsername != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    activityFilterUserId = null;
                    activityFilterUsername = null;
                  });
                  _loadActivities();
                },
                icon: const Icon(Icons.clear),
                label: const Text('Show All Activities'),
              ),
            ),
          ),
        Expanded(
          child: filteredActivities.isEmpty
              ? const Center(child: Text('No activities found.'))
              : ListView.builder(
                  itemCount: filteredActivities.length,
                  itemBuilder: (context, i) {
                    final a = filteredActivities[i];
                    final username = a['username'] ?? 'Unknown';
                    final action = a['action'] ?? '';
                    final details = a['details'] ?? '';
                    final createdAt = DateTime.tryParse(a['created_at'] ?? '')?.toLocal();

                    return Card(
                      margin: EdgeInsets.symmetric(
                        horizontal: _isMobile ? 8 : 12,
                        vertical: _isMobile ? 2 : 4,
                      ),
                      child: ListTile(
                        leading: Icon(Icons.history, size: _isMobile ? 20 : 24),
                        title: Text(
                          '$username • $action',
                          style: TextStyle(fontSize: _isMobile ? 14 : 16),
                        ),
                        subtitle: Text(
                          details,
                          style: TextStyle(fontSize: _isMobile ? 12 : 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          createdAt != null
                              ? DateFormat('MM-dd HH:mm').format(createdAt)
                              : '',
                          style: TextStyle(
                            fontSize: _isMobile ? 10 : 12, 
                            color: Colors.grey
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatTime(dynamic input) {
    try {
      final dt = DateTime.parse(input.toString()).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  String _formatDate(dynamic input) {
    try {
      final dt = DateTime.parse(input.toString()).toLocal();
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = isDarkMode ? ThemeData.dark() : ThemeData.light();
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          actions: [
            // DAGDAG: Logout button
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _confirmLogout,
              tooltip: 'Logout',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchAllData,
              tooltip: 'Refresh Data',
            ),
            IconButton(
              icon: Icon(isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
              onPressed: _toggleTheme,
              tooltip: 'Toggle Theme',
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(_isMobile ? 40 : 48),
            child: Container(
              color: Theme.of(context).appBarTheme.backgroundColor,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelPadding: EdgeInsets.symmetric(
                  horizontal: _isMobile ? 12 : 16,
                  vertical: _isMobile ? 8 : 12,
                ),
                tabs: [
                  _buildTab(Icons.dashboard, 'Dashboard'),
                  _buildTab(Icons.people, 'Users'),
                  _buildTab(Icons.pending, 'Pending'),
                  _buildTab(Icons.folder, 'Resources'),
                  _buildTab(Icons.video_library, 'Videos'),
                  _buildTab(Icons.article, 'Articles'),
                  _buildTab(Icons.quiz, 'Quizzes'),
                  _buildTab(Icons.meeting_room, 'Rooms'),
                  _buildTab(Icons.history, 'Activities'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDashboardTab(),
            _buildUsersTab(),
            _buildPendingTab(),
            _buildResourcesTab(),
            _buildVideosTab(),
            _buildArticlesTab(),
            _buildQuizzesTab(),
            _buildRoomsTab(),
            _buildActivitiesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(IconData icon, String label) {
    return _isMobile
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label),
            ],
          );
  }

  @override
  void dispose() {
    supabase.removeAllChannels();
    _tabController.dispose();
    super.dispose();
  }
}