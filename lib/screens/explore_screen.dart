import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/gonordic_theme.dart';
import '../widgets/gonordic_banner.dart';
import 'booking_wizard_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _routeId = 'ROUTE-CPH-OSL';
  String _tripType = 'CRUISE';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  final int _adults = 2;
  final bool _hasVehicle = true;

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(
        title: const Text('Go Nordic Cruiseline'),
        actions: [
          IconButton(
            icon: Icon(user != null ? Icons.account_circle : Icons.person_outline),
            tooltip: 'Profil',
            onPressed: () {
              if (user != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => setState(() {}));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())).then((_) => setState(() {}));
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          const GoNordicBanner(
            badgeText: 'MINICRUISE TILBUD',
            text: 'Sejl København-Oslo tur/retur fra kun 890 DKK',
          ),
          _buildHero(),
          _buildProfileBar(user),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSearchCard(),
          ),
          _buildPriceStrip(),
          _buildHighlights(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Stack(
      children: [
        SizedBox(
          height: 200,
          width: double.infinity,
          child: Image.asset(
            'assets/gonordic/images/hero-people.jpg',
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => Container(color: GoNordicTheme.pineDark),
          ),
        ),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [GoNordicTheme.pineDark.withValues(alpha: 0.9), Colors.transparent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: GoNordicTheme.lime, borderRadius: BorderRadius.circular(12)),
                child: const Text('DAGLIGE AFGANGE KØBENHAVN ⇄ OSLO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: GoNordicTheme.pineDark)),
              ),
              const SizedBox(height: 6),
              const Text('Oplev Norge fra søsiden', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const Text('2 nætter til søs • Gastronomi • Panoramadæk', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileBar(dynamic user) {
    if (user != null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F4EA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF34A853).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const CircleAvatar(radius: 16, backgroundColor: GoNordicTheme.pine, child: Icon(Icons.check, size: 16, color: GoNordicTheme.lime)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hej, ${user.fullName} (${user.clubTier}) 👋', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: GoNordicTheme.pine)),
                  Text('Stamdata, pas og elbil (${user.savedVehiclePlate}) er klar til brug.', style: const TextStyle(fontSize: 11, color: Color(0xFF1E6460))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GoNordicTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_circle, color: GoNordicTheme.teal, size: 26),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Log ind for at bruge dine gemte data', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                Text('Udfylder bilnummer og kontaktoplysninger automatisk.', style: TextStyle(fontSize: 10, color: GoNordicTheme.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())).then((_) => setState(() {})),
            child: const Text('Log ind', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _tab('MiniCruise', 'CRUISE'),
                const SizedBox(width: 8),
                _tab('Færgeoverfart', 'ONEWAY'),
              ],
            ),
            const Divider(height: 20),
            InkWell(
              onTap: () {
                setState(() {
                  _routeId = _routeId == 'ROUTE-CPH-OSL' ? 'ROUTE-OSL-CPH' : 'ROUTE-CPH-OSL';
                });
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: GoNordicTheme.sandLight, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.directions_boat, color: GoNordicTheme.pine, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_routeId == 'ROUTE-CPH-OSL' ? 'København → Oslo' : 'Oslo → København', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const Icon(Icons.swap_horiz, color: GoNordicTheme.teal),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: GoNordicTheme.sandLight, borderRadius: BorderRadius.circular(10)),
                      child: Text('${_date.day}/${_date.month}-${_date.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: GoNordicTheme.sandLight, borderRadius: BorderRadius.circular(10)),
                    child: Text('$_adults voksne ${_hasVehicle ? "• Bil" : ""}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingWizardScreen()));
                },
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Find Afgange & Book Kahyt →'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String title, String type) {
    final active = _tripType == type;
    return InkWell(
      onTap: () => setState(() => _tripType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? GoNordicTheme.pine : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? Colors.white : GoNordicTheme.textPrimary)),
      ),
    );
  }

  Widget _buildPriceStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text('LAVPRISKALENDER (14 DAGE)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: GoNordicTheme.textSecondary)),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: 14,
            itemBuilder: (ctx, i) {
              final d = DateTime.now().add(Duration(days: i + 1));
              return Container(
                width: 68,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: GoNordicTheme.border)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    const Text('890,-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GoNordicTheme.pine)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHighlights() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OPLEVELSER OM BORD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: GoNordicTheme.textSecondary)),
          const SizedBox(height: 8),
          _item('Skandinavisk Gastronomi & Buffeter', '7 Seas buffet og frisk morgenmad.', 'assets/gonordic/images/chef-kitchen.jpg'),
          _item('Panoramadæk & Saloner', 'Udsigt over Kattegat og Oslofjorden.', 'assets/gonordic/images/family-window.jpg'),
          _item('Tax-Free Sea Shop', 'Kosmetik, slik og mærkevarer op til 40% rabat.', 'assets/gonordic/images/taxfree-shop.jpg'),
        ],
      ),
    );
  }

  Widget _item(String title, String sub, String img) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Image.asset(img, width: 85, height: 65, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 85, height: 65, color: GoNordicTheme.pineDark)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(sub, style: const TextStyle(fontSize: 10, color: GoNordicTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
