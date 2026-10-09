import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../theme/gonordic_theme.dart';
import 'boarding_pass_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final BookingModel booking;
  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late BookingModel _currentBooking;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
  }

  void _handleCheckIn() async {
    final res = await BookingService().checkInBookingWithResult(_currentBooking.pnr);
    if (!mounted) return;
    if (res.success && res.booking != null) {
      setState(() {
        _currentBooking = res.booking!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GoNordicTheme.success,
          content: Text('✓ Mobil Check-in gennemført! Boardingkort er udstedt.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GoNordicTheme.error,
          content: Text(res.errorMessage ?? 'Check-in afvist af serveren.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(title: Text('Booking ${_currentBooking.pnr}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_currentBooking.routeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('${_currentBooking.departureDate} kl. ${_currentBooking.departureTime} • ${_currentBooking.vesselName}', style: const TextStyle(color: GoNordicTheme.teal, fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    _item('Status', _currentBooking.status),
                    _item('Kahyt', _currentBooking.cabinTitle),
                    _item('Passagerer', _currentBooking.passengers.map((p) => p.fullName).join(', ')),
                    if (_currentBooking.vehicle != null) _item('Køretøj', '${_currentBooking.vehicle!.licensePlate} (${_currentBooking.vehicle!.category})'),
                    _item('Samlet pris', '${_currentBooking.totalAmountDkk.toInt()} DKK (Betalt)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => BoardingPassScreen(booking: _currentBooking)));
                },
                icon: const Icon(Icons.qr_code),
                label: const Text('Vis QR Boardingkort'),
                style: ElevatedButton.styleFrom(backgroundColor: GoNordicTheme.pine, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
              ),
            ),
            if (!_currentBooking.isCheckedIn) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleCheckIn,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Gennemfør Mobil Check-in'),
                  style: ElevatedButton.styleFrom(backgroundColor: GoNordicTheme.lime, foregroundColor: GoNordicTheme.pineDark, padding: const EdgeInsets.all(14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _item(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary, fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
