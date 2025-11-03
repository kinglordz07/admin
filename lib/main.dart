import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_panel/admin_panel_screen.dart';
import 'admin_panel/secure_admin_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: "assets/.env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CodexHub Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 🎨 LIGHT MODE - Soft and professional
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF2563EB),    // Nice blue
          secondary: const Color(0xFF64748B),  // Slate gray
          surface: Colors.white,
          surfaceContainerHighest: const Color(0xFFF8FAFC), // Very light gray background
          onSurface: const Color(0xFF0F172A), // Dark text
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
        ),
        cardColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
          ),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        // 🌙 DARK MODE - Easy on the eyes
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF60A5FA),    // Light blue
          secondary: const Color(0xFF94A3B8),  // Light slate
          surface: const Color(0xFF1E293B),    // Dark surface
          surfaceContainerHighest: const Color(0xFF0F172A), // Dark background
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 1,
          centerTitle: true,
        ),
        cardColor: const Color(0xFF1E293B),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade700),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade700),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 2),
          ),
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _supabase = Supabase.instance.client;
  User? _user;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _user = _supabase.auth.currentUser;
    
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        setState(() {
          _user = data.session?.user;
          _isCheckingAuth = false;
        });
      } else if (event == AuthChangeEvent.signedOut) {
        setState(() {
          _user = null;
          _isCheckingAuth = false;
        });
      } else if (event == AuthChangeEvent.initialSession) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isCheckingAuth) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    });
  }

  Future<bool> _isUserAdmin(String userId) async {
    try {
      final result = await _supabase.rpc('is_admin', params: {'user_id': userId});
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Admin check failed: $e');
      return false;
    }
  }

  // DAGDAG: Logout function
  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully logged out'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildLoadingScreen() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Smooth animated icon
            AnimatedContainer(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              child: Icon(
                Icons.admin_panel_settings,
                size: 80,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Loading with better styling
            Column(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Securing Admin Portal...',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Checking authentication & permissions',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return _buildLoadingScreen();
    }

    if (_user != null) {
      return FutureBuilder<bool>(
        future: _isUserAdmin(_user!.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
          }

          if (snapshot.hasData && snapshot.data == true) {
            return AdminPanelScreen(onLogout: _logout); // DAGDAG: Pass logout function
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Access denied: User is not an administrator'),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            });
            return const SecureAdminLoginScreen();
          }
        },
      );
    } else {
      return const SecureAdminLoginScreen();
    }
  }
}