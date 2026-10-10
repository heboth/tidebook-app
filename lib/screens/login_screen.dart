import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/texts_service.dart';
import '../theme/gonordic_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController(text: 'kunde');
  final _passController = TextEditingController(text: 'Kunde2026!');
  String? _error;
  bool _loading = false;

  void _login() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    final res = await AuthService().loginCustomer(
      usernameOrEmail: _userController.text,
      password: _passController.text,
    );

    setState(() => _loading = false);

    if (!mounted) return;
    if (!res.success) {
      setState(() => _error = res.errorMessage);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: GoNordicTheme.success, content: Text(tr('login.welcome', {'name': res.user!.fullName}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final user = auth.currentUser;

    if (user != null) {
      return Scaffold(
        backgroundColor: GoNordicTheme.sand,
        appBar: AppBar(title: Text(tr('login.profileTitle'))),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const CircleAvatar(radius: 28, backgroundColor: GoNordicTheme.pine, child: Icon(Icons.person, color: Colors.white)),
                      const SizedBox(height: 10),
                      Text(user.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(user.email, style: const TextStyle(color: GoNordicTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    auth.logout();
                    setState(() {});
                  },
                  child: Text(tr('login.logout')),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(title: Text(tr('login.title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF59E0B))),
              child: Text(tr('login.individualOnly'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/gonordic/app_icon.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Image.asset(
                      'assets/gonordic/logo.png',
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => const Text('Go Nordic Cruiseline', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(tr('login.heading'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _userController, decoration: InputDecoration(labelText: tr('login.usernameLabel'))),
                    const SizedBox(height: 10),
                    TextField(controller: _passController, obscureText: true, decoration: InputDecoration(labelText: tr('login.passwordLabel'))),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: GoNordicTheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _login, child: Text(_loading ? tr('login.verifying') : tr('login.submit')))),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(label: Text(tr('login.demoCustomer')), onPressed: () { _userController.text = 'kunde'; _passController.text = 'Kunde2026!'; }),
                        ActionChip(label: Text(tr('login.demoAgent')), onPressed: () { _userController.text = 'rejseagent'; _passController.text = 'Agent2026!'; }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
