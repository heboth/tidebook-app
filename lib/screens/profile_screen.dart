import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/gonordic_theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _editData(UserModel user) {
    final nameCtrl = TextEditingController(text: user.fullName);
    final phoneCtrl = TextEditingController(text: user.phone);
    final addrCtrl = TextEditingController(text: user.address);
    final cityCtrl = TextEditingController(text: user.city);
    final postCtrl = TextEditingController(text: user.postalCode);
    final plateCtrl = TextEditingController(text: user.savedVehiclePlate);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rediger Profil & Stamdata', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Fulde Navn')),
              const SizedBox(height: 6),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Mobilnummer')),
              const SizedBox(height: 6),
              TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Adresse')),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: TextField(controller: postCtrl, decoration: const InputDecoration(labelText: 'Postnr'))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'By'))),
                ],
              ),
              const SizedBox(height: 6),
              TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Nummerplade (Bil)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuller')),
          ElevatedButton(
            onPressed: () {
              final up = user.copyWith(
                fullName: nameCtrl.text,
                phone: phoneCtrl.text,
                address: addrCtrl.text,
                postalCode: postCtrl.text,
                city: cityCtrl.text,
                savedVehiclePlate: plateCtrl.text,
              );
              AuthService().updateProfile(up);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Gem'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final user = auth.currentUser;
    if (user == null) {
      return _buildLoggedOut(auth);
    }
    return _buildLoggedIn(auth, user);
  }

  Widget _buildLoggedOut(AuthService auth) {
    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(title: const Text('Min Profil')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(radius: 30, backgroundColor: GoNordicTheme.pine, child: Icon(Icons.person, color: Colors.white, size: 32)),
                  const SizedBox(height: 12),
                  const Text('Log ind på din profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Gem dine stamdata, adresse og bilnummer, så din booking udfyldes automatisk.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())).then((_) => setState(() {})),
                      child: const Text('Log ind / Opret profil'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      auth.loginAsDemoCustomer();
                      setState(() {});
                    },
                    child: const Text('Demo: Log ind som Mads Jensen'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedIn(AuthService auth, UserModel user) {
    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(
        title: const Text('Min Profil & Personlige Data'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () { auth.logout(); setState(() {}); }),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [GoNordicTheme.pineDark, Color(0xFF0A4E4F)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GO NORDIC CLUB', style: TextStyle(color: GoNordicTheme.lime, fontWeight: FontWeight.w900, fontSize: 12)),
                    Text(user.clubTier.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(user.fullName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Medlemsnr: ${user.clubMemberNumber}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 8),
                Text('Opsparede bonuspoint: ${user.clubPoints}', style: const TextStyle(color: GoNordicTheme.lime, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Personlige Stamdata', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.edit, size: 18, color: GoNordicTheme.teal), onPressed: () => _editData(user)),
                    ],
                  ),
                  const Divider(),
                  _row('Navn', user.fullName),
                  _row('E-mail', user.email),
                  _row('Mobil', user.phone),
                  _row('Adresse', '${user.address}, ${user.postalCode} ${user.city}'),
                  _row('Nationalitet', user.nationality),
                  _row('Pasnummer', user.passportNumber),
                  _row('Fødselsdato', user.birthDate),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gemt Køretøj', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _row('Nummerplade', user.savedVehiclePlate),
                  _row('Køretøjstype', 'Almindelig Personbil'),
                  _row('Drivmiddel', user.isElectricVehicle ? '⚡ 100% Elektrisk (Elbil)' : 'Benzin/Diesel'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 95, child: Text(label, style: const TextStyle(fontSize: 11, color: GoNordicTheme.textSecondary, fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
