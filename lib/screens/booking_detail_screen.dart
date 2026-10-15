import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../services/texts_service.dart';
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
        SnackBar(
          backgroundColor: GoNordicTheme.success,
          content: Text(tr('bookingDetail.checkInDone')),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GoNordicTheme.error,
          content: Text(res.errorMessage ?? tr('bookingDetail.checkInRejected')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(title: Text(tr('bookingDetail.title', {'pnr': _currentBooking.pnr}))),
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
                    Text(tr('bookingDetail.departure', {'date': _currentBooking.departureDate, 'time': _currentBooking.departureTime, 'ship': _currentBooking.vesselName}), style: const TextStyle(color: GoNordicTheme.teal, fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    _item(tr('bookingDetail.status'), _currentBooking.status),
                    _item(tr('bookingDetail.cabin'), _currentBooking.cabinLabel),
                    _item(tr('bookingDetail.passengers'), _currentBooking.passengers.map((p) => p.fullName).join(', ')),
                    if (_currentBooking.vehicle != null) _item(tr('bookingDetail.vehicle'), '${_currentBooking.vehicle!.licensePlate} (${_currentBooking.vehicle!.category})'),
                    _item(tr('bookingDetail.totalPrice'), tr('bookingDetail.totalPaid', {'amount': _currentBooking.totalAmountDkk.toInt()})),
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
                label: Text(tr('bookingDetail.showBoardingPass')),
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
                  label: Text(tr('bookingDetail.checkIn')),
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
