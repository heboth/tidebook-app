import 'package:flutter/material.dart';
import '../services/booking_service.dart';
import '../widgets/booking_card.dart';
import '../theme/gonordic_theme.dart';
import 'booking_detail_screen.dart';
import 'boarding_pass_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _pnrController = TextEditingController();
  final _emailController = TextEditingController();
  String? _searchError;

  void _searchBooking() async {
    setState(() => _searchError = null);
    final pnr = _pnrController.text.trim();
    final emailOrLastName = _emailController.text.trim();

    if (pnr.isEmpty || emailOrLastName.isEmpty) {
      setState(() => _searchError = 'Indtast venligst både bookingnummer (PNR) og e-mail/efternavn.');
      return;
    }

    final res = await BookingService().lookupBooking(pnr: pnr, emailOrLastName: emailOrLastName);
    if (!mounted) return;
    if (!res.success) {
      setState(() => _searchError = res.errorMessage);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: GoNordicTheme.success, content: Text('✓ Booking fundet: ${res.booking!.pnr}')),
      );
    }
  }

  void _quickFill(String pnr, String email) {
    _pnrController.text = pnr;
    _emailController.text = email;
    _searchBooking();
  }

  @override
  Widget build(BuildContext context) {
    final bookings = BookingService().bookings;

    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(title: const Text('Mine Bookinger & Boardingkort')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Find Din Reservation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text('Indtast bookingnummer (PNR) og e-mail for at hente dit boardingkort.', style: TextStyle(fontSize: 11, color: GoNordicTheme.textSecondary)),
                    const SizedBox(height: 12),
                    TextField(controller: _pnrController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'BOOKINGNUMMER (PNR)', hintText: 'F.eks. TIDE-9021')),
                    const SizedBox(height: 10),
                    TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'E-MAIL ELLER EFTERNAVN', hintText: 'F.eks. mads.jensen@example.dk')),
                    if (_searchError != null) ...[
                      const SizedBox(height: 10),
                      Text(_searchError!, style: const TextStyle(color: GoNordicTheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(onPressed: _searchBooking, icon: const Icon(Icons.search), label: const Text('Find Booking')),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        const Text('Test:', style: TextStyle(fontSize: 11, color: GoNordicTheme.textSecondary)),
                        ActionChip(label: const Text('TIDE-9021'), onPressed: () => _quickFill('TIDE-9021', 'mads.jensen@example.dk')),
                        ActionChip(label: const Text('TIDE-4412'), onPressed: () => _quickFill('TIDE-4412', 'henrik.lindqvist@oslo-fjord.no')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text('DINE RESERVATIONER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GoNordicTheme.textSecondary)),
          ),
          const SizedBox(height: 6),
          ...bookings.map((b) => BookingCard(
            booking: b,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b))),
            onShowBoardingPass: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BoardingPassScreen(booking: b))),
            onCheckIn: () {
              BookingService().checkInBooking(b.pnr);
              setState(() {});
            },
          )),
        ],
      ),
    );
  }
}
