import 'package:flutter/material.dart';
import '../services/booking_service.dart';
import '../services/texts_service.dart';
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
      setState(() => _searchError = tr('myBookings.missingFields'));
      return;
    }

    final res = await BookingService().lookupBooking(pnr: pnr, emailOrLastName: emailOrLastName);
    if (!mounted) return;
    if (!res.success) {
      setState(() => _searchError = res.errorMessage);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: GoNordicTheme.success, content: Text(tr('myBookings.found', {'pnr': res.booking!.pnr}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BookingService(),
      builder: (context, _) {
        final bookings = BookingService().bookings;

        return Scaffold(
          backgroundColor: GoNordicTheme.sand,
          appBar: AppBar(title: Text(tr('myBookings.title'))),
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
                        Text(tr('myBookings.findHeading'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(tr('myBookings.findIntro'), style: const TextStyle(fontSize: 11, color: GoNordicTheme.textSecondary)),
                        const SizedBox(height: 12),
                        TextField(controller: _pnrController, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: tr('myBookings.pnrLabel'), hintText: tr('myBookings.pnrHint'))),
                        const SizedBox(height: 10),
                        TextField(controller: _emailController, decoration: InputDecoration(labelText: tr('myBookings.emailLabel'), hintText: tr('myBookings.emailHint'))),
                        if (_searchError != null) ...[
                          const SizedBox(height: 10),
                          Text(_searchError!, style: const TextStyle(color: GoNordicTheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(onPressed: _searchBooking, icon: const Icon(Icons.search), label: Text(tr('myBookings.findButton'))),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(tr('myBookings.yourReservations'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GoNordicTheme.textSecondary)),
              ),
              const SizedBox(height: 6),
              ...bookings.map((b) => BookingCard(
                booking: b,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b))),
                onShowBoardingPass: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BoardingPassScreen(booking: b))),
                onCheckIn: () async {
                  final res = await BookingService().checkInBookingWithResult(b.pnr);
                  if (!context.mounted) return;
                  if (res.success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: GoNordicTheme.success,
                        content: Text(tr('myBookings.checkInDone')),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: GoNordicTheme.error,
                        content: Text(res.errorMessage ?? tr('myBookings.checkInRejected')),
                      ),
                    );
                  }
                  setState(() {});
                },
              )),
            ],
          ),
        );
      },
    );
  }
}
