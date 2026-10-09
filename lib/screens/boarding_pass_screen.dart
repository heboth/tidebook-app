import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../theme/gonordic_theme.dart';
import '../widgets/maritime_qr_widget.dart';

class BoardingPassScreen extends StatelessWidget {
  final BookingModel booking;
  const BoardingPassScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final leadPax = booking.passengers.isNotEmpty
        ? booking.passengers.first.fullName
        : booking.leadContactName;

    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(title: const Text('Boardingkort')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GoNordicTheme.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: GoNordicTheme.pineDark,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        booking.routeName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      booking.isCheckedIn ? 'TJEKKET IND' : 'KLAR',
                      style: const TextStyle(color: GoNordicTheme.lime, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: MaritimeQrWidget(
                  pnr: booking.pnr,
                  departureDate: booking.departureDate,
                  cabin: booking.cabinNumbers.isNotEmpty ? booking.cabinNumbers.first : null,
                  size: 180,
                ),
              ),
              Text(
                booking.pnr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w900, color: GoNordicTheme.pine),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row('Passager', leadPax, 'Afgang', '${booking.departureDate} ${booking.departureTime}'),
                    const SizedBox(height: 12),
                    _row('Færge', booking.vesselName, 'Kahyt', booking.cabinTitle),
                    const SizedBox(height: 12),
                    _row('Gate', booking.gateNumber, 'Køretøj', booking.vehicle?.licensePlate ?? 'Gående'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String l1, String v1, String l2, String v2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l1.toUpperCase(), style: const TextStyle(fontSize: 10, color: GoNordicTheme.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(v1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l2.toUpperCase(), style: const TextStyle(fontSize: 10, color: GoNordicTheme.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(v2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
