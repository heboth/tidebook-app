import 'package:flutter/material.dart';
import '../models/cabin_model.dart';
import '../models/addon_model.dart';
import '../models/passenger_model.dart';
import '../models/booking_model.dart';
import '../services/auth_service.dart';
import '../services/booking_service.dart';
import '../theme/gonordic_theme.dart';
import '../widgets/cabin_card.dart';
import 'boarding_pass_screen.dart';
import 'login_screen.dart';

class BookingWizardScreen extends StatefulWidget {
  const BookingWizardScreen({super.key});

  @override
  State<BookingWizardScreen> createState() => _BookingWizardScreenState();
}

class _BookingWizardScreenState extends State<BookingWizardScreen> {
  int _step = 1;
  String _routeId = 'ROUTE-CPH-OSL';
  CabinModel? _cabin;
  final Map<String, int> _addons = {};
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  BookingModel? _booked;

  @override
  void initState() {
    super.initState();
    final u = AuthService().currentUser;
    _nameCtrl = TextEditingController(text: u?.fullName ?? 'Mads Jensen');
    _emailCtrl = TextEditingController(text: u?.email ?? 'mads.jensen@example.dk');
    _phoneCtrl = TextEditingController(text: u?.phone ?? '+45 20 30 40 50');
  }

  void _useProfileData() {
    final u = AuthService().currentUser;
    if (u != null) {
      setState(() {
        _nameCtrl.text = u.fullName;
        _emailCtrl.text = u.email;
        _phoneCtrl.text = u.phone;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: GoNordicTheme.success, content: Text('✓ Kontaktoplysninger udfyldt fra ${u.fullName}s profil')),
      );
    }
  }

  double get _total {
    double s = 890 + (_cabin?.priceDkk ?? 0);
    _addons.forEach((k, v) {
      final a = AddOnModel.defaultAddOns.firstWhere((x) => x.id == k);
      s += a.priceDkk * v;
    });
    return s;
  }

  void _finish() {
    final pnr = 'TIDE-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final r = BookingService().routes.firstWhere((x) => x.id == _routeId);
    final b = BookingModel(
      pnr: pnr,
      bookingCode: 'BK-$pnr',
      routeId: _routeId,
      routeName: r.name,
      departureId: 'DEP-NEW',
      departureDate: DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0],
      departureTime: '16:30',
      arrivalTime: '10:00 (+1)',
      vesselName: 'Crown Seaways',
      status: 'CONFIRMED',
      ticketClass: 'PREMIUM',
      passengers: [
        PassengerModel(id: 'P1', firstName: _nameCtrl.text.split(' ').first, lastName: _nameCtrl.text.split(' ').last, type: PassengerType.adult)
      ],
      selectedCabinIds: [_cabin?.id ?? 'CAB-STD'],
      cabinTitle: _cabin?.title ?? 'Standard Kahyt',
      cabinNumbers: ['CAB-7104'],
      addOns: _addons.entries.map((e) => {'name': e.key, 'quantity': e.value}).toList(),
      leadContactName: _nameCtrl.text,
      leadContactEmail: _emailCtrl.text,
      leadContactPhone: '+45 20 30 40 50',
      totalAmountDkk: _total,
      paymentStatus: 'PAID',
    );
    BookingService().addBooking(b);
    setState(() {
      _booked = b;
      _step = 5;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(title: Text('Book Rejse • Trin $_step/5')),
      body: _buildStep(),
    );
  }

  Widget _buildStep() {
    if (_step == 1) return _step1();
    if (_step == 2) return _step2();
    if (_step == 3) return _step3();
    if (_step == 4) return _step4();
    return _step5();
  }

  Widget _step1() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('1. Vælg Rute', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      Card(
        child: Column(
          children: BookingService().routes.map((r) => ListTile(
            title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            leading: Icon(
              _routeId == r.id ? Icons.radio_button_checked : Icons.radio_button_off,
              color: GoNordicTheme.pine,
            ),
            onTap: () => setState(() => _routeId = r.id),
          )).toList(),
        ),
      ),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: () => setState(() => _step = 2), child: const Text('Vælg Kahyt →')),
    ],
  );

  Widget _step2() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('2. Vælg Kahyt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ...CabinModel.defaultCabins.map((c) => CabinCard(
        cabin: c, isSelected: _cabin?.id == c.id,
        onSelect: () => setState(() => _cabin = c),
      )),
      ElevatedButton(onPressed: _cabin == null ? null : () => setState(() => _step = 3), child: const Text('Tilvalg →')),
    ],
  );

  Widget _step3() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('3. Tilvalg & Måltider', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ...AddOnModel.defaultAddOns.map((a) => Card(
        child: CheckboxListTile(
          title: Text(a.name), subtitle: Text('${a.priceDkk.toInt()} DKK'),
          value: _addons.containsKey(a.id), activeColor: GoNordicTheme.pine,
          onChanged: (v) => setState(() {
            if (v == true) {
              _addons[a.id] = 1;
            } else {
              _addons.remove(a.id);
            }
          }),
        ),
      )),
      ElevatedButton(onPressed: () => setState(() => _step = 4), child: const Text('Kontaktoplysninger →')),
    ],
  );

  Widget _step4() {
    final user = AuthService().currentUser;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('4. Kontaktoplysninger & Profil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (user != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF34A853).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF34A853), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Logget ind: ${user.fullName} (${user.clubTier})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                TextButton(
                  onPressed: _useProfileData,
                  child: const Text('Brug profil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GoNordicTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 20, color: GoNordicTheme.teal),
                const SizedBox(width: 8),
                const Expanded(child: Text('Log ind for hurtig udfyldelse', style: TextStyle(fontSize: 11))),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())).then((_) {
                      setState(() {
                        final u = AuthService().currentUser;
                        if (u != null) {
                          _nameCtrl.text = u.fullName;
                          _emailCtrl.text = u.email;
                          _phoneCtrl.text = u.phone;
                        }
                      });
                    });
                  },
                  child: const Text('Log ind', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'FULDE NAVN')),
                const SizedBox(height: 8),
                TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'E-MAIL')),
                const SizedBox(height: 8),
                TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'MOBILNUMMER')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Total: ${_total.toInt()} DKK', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GoNordicTheme.pine)),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _finish, child: const Text('Gennemfør & Udsted Billet')),
      ],
    );
  }

  Widget _step5() => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('assets/gonordic/app_icon.png', width: 64, height: 64, fit: BoxFit.cover),
          ),
          const SizedBox(height: 10),
          const Icon(Icons.check_circle, color: GoNordicTheme.success, size: 48),
          const SizedBox(height: 8),
          const Text('Booking Gennemført!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${_booked?.pnr}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: GoNordicTheme.pine)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BoardingPassScreen(booking: _booked!))),
            child: const Text('Vis QR Boardingkort'),
          ),
        ],
      ),
    ),
  );
}
