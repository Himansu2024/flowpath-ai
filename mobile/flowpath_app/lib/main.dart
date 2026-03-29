// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/navigation_provider.dart';
import 'screens/home_screen.dart';
import 'screens/navigation_screen.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Dark system UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D1117),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const FlowPathApp());
}

class FlowPathApp extends StatelessWidget {
  const FlowPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService    = ApiService();
    final socketService = SocketService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => NavigationProvider(
            apiService:    apiService,
            socketService: socketService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'FlowPath AI',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const _AppShell(),
        routes: {
          '/home':     (_) => const HomeScreen(),
          '/navigate': (_) => const NavigationScreen(),
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00E676),
        brightness: Brightness.dark,
        surface: const Color(0xFF0D1117),
        primary: const Color(0xFF00E676),
        secondary: const Color(0xFF00B0FF),
        error: const Color(0xFFFF1744),
      ),
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      cardColor: const Color(0xFF0E1520),
      dividerColor: const Color(0xFF1E2A3A),

      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.w900),
        headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: Color(0xFFE8F0FF)),
        bodyMedium: TextStyle(color: Color(0xFFE8F0FF)),
        labelSmall: TextStyle(color: Color(0xFF5A6A88), letterSpacing: 1.5),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0E1520),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E2A3A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E2A3A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF5A6A88)),
        hintStyle: const TextStyle(color: Color(0xFF5A6A88)),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00E676),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}

// ── App Shell: handles auth state ────────────────────────────
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  @override
  void initState() {
    super.initState();
    // Attempt to restore session from saved JWT token after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().tryAutoLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) return const _SplashScreen();
    if (auth.isLoggedIn) return const HomeScreen();
    return const _LoginScreen();
  }
}

// ── Splash Screen ─────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('FLOWPATH',
            style: TextStyle(
              fontFamily: 'Orbitron', fontSize: 34,
              fontWeight: FontWeight.w900, color: Color(0xFF00E676),
              letterSpacing: 4,
              shadows: [Shadow(color: Color(0xFF00E676), blurRadius: 24)],
            )),
          SizedBox(height: 8),
          Text('AI Traffic Navigator',
            style: TextStyle(color: Color(0xFF5A6A88), fontSize: 14, letterSpacing: 2)),
          SizedBox(height: 48),
          CircularProgressIndicator(
            color: Color(0xFF00E676),
            strokeWidth: 2,
          ),
        ]),
      ),
    );
  }
}

// ── Login / Register Screen ───────────────────────────────────
class _LoginScreen extends StatefulWidget {
  const _LoginScreen();

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _nameCtrl   = TextEditingController();
  bool  _isLogin    = true;
  bool  _obscure    = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    final success = _isLogin
        ? await auth.login(_emailCtrl.text.trim(), _passCtrl.text)
        : await auth.register(_emailCtrl.text.trim(), _passCtrl.text, _nameCtrl.text.trim());

    if (success && mounted) {
      navigator.pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 40),
              const Text('FLOWPATH',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Orbitron', fontSize: 30, fontWeight: FontWeight.w900,
                  color: Color(0xFF00E676), letterSpacing: 4,
                  shadows: [Shadow(color: Color(0xFF00E676), blurRadius: 20)],
                )),
              const SizedBox(height: 6),
              const Text('AI Traffic Navigator',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF5A6A88), fontSize: 13, letterSpacing: 2)),
              const SizedBox(height: 50),

              // Full name (register only)
              if (!_isLogin) ...[
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline, color: Color(0xFF5A6A88)),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (v) => (v?.length ?? 0) < 2 ? 'Enter your name' : null,
                ),
                const SizedBox(height: 16),
              ],

              // Email
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF5A6A88)),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (v) => (v?.contains('@') ?? false) ? null : 'Enter valid email',
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF5A6A88)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF5A6A88)),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (v) => (v?.length ?? 0) < 8 ? 'Min 8 characters' : null,
              ),
              const SizedBox(height: 28),

              // Error
              if (auth.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFF1744),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x4DFF1744)),
                  ),
                  child: Text(auth.error!,
                    style: const TextStyle(color: Color(0xFFFF1744), fontSize: 13)),
                ),

              // Submit button
              ElevatedButton(
                onPressed: auth.isLoading ? null : _submit,
                child: auth.isLoading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(_isLogin ? 'Sign In' : 'Create Account',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),

              // Toggle
              TextButton(
                onPressed: () => setState(() { _isLogin = !_isLogin; }),
                child: Text(
                  _isLogin
                      ? "Don't have an account? Register"
                      : 'Already have an account? Sign In',
                  style: const TextStyle(color: Color(0xFF00E676)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
