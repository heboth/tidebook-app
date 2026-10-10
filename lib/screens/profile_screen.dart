import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/texts_service.dart';
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
        title: Text(tr('profile.editTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: tr('profile.fullName'))),
              const SizedBox(height: 6),
              TextField(controller: phoneCtrl, decoration: InputDecoration(labelText: tr('profile.mobileNumber'))),
              const SizedBox(height: 6),
              TextField(controller: addrCtrl, decoration: InputDecoration(labelText: tr('profile.address'))),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: TextField(controller: postCtrl, decoration: InputDecoration(labelText: tr('profile.postalCode')))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextField(controller: cityCtrl, decoration: InputDecoration(labelText: tr('profile.city')))),
                ],
              ),
              const SizedBox(height: 6),
              TextField(controller: plateCtrl, decoration: InputDecoration(labelText: tr('profile.licensePlateCar'))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('profile.cancel'))),
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
            child: Text(tr('profile.save')),
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
      appBar: AppBar(title: Text(tr('profile.title'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/gonordic/app_icon.png', width: 64, height: 64, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                  Text(tr('profile.loginHeading'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(tr('profile.loginIntro'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())).then((_) => setState(() {})),
                      child: Text(tr('profile.loginOrCreate')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      auth.loginAsDemoCustomer();
                      setState(() {});
                    },
                    child: Text(tr('profile.demoLogin')),
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
        title: Text(tr('profile.loggedInTitle')),
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
                    Image.asset('assets/gonordic/logo_white.png', height: 16, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Text('GO NORDIC CLUB', style: TextStyle(color: GoNordicTheme.lime, fontWeight: FontWeight.w900, fontSize: 12))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                      child: Text(user.clubTier.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(user.fullName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(tr('profile.memberNumber', {'number': user.clubMemberNumber}), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 8),
                Text(tr('profile.bonusPoints', {'points': user.clubPoints}), style: const TextStyle(color: GoNordicTheme.lime, fontWeight: FontWeight.bold, fontSize: 13)),
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
                      Text(tr('profile.personalData'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.edit, size: 18, color: GoNordicTheme.teal), onPressed: () => _editData(user)),
                    ],
                  ),
                  const Divider(),
                  _row(tr('profile.name'), user.fullName),
                  _row(tr('profile.email'), user.email),
                  _row(tr('profile.mobile'), user.phone),
                  _row(tr('profile.addressRow'), '${user.address}, ${user.postalCode} ${user.city}'),
                  _row(tr('profile.nationality'), user.nationality),
                  _row(tr('profile.passportNumber'), user.passportNumber),
                  _row(tr('profile.birthDate'), user.birthDate),
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
                  Text(tr('profile.savedVehicle'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _row(tr('profile.licensePlate'), user.savedVehiclePlate),
                  _row(tr('profile.vehicleType'), tr('profile.vehicleTypeCar')),
                  _row(tr('profile.fuel'), user.isElectricVehicle ? tr('profile.fuelElectric') : tr('profile.fuelCombustion')),
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
