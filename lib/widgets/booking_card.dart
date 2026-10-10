import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/texts_service.dart';
import '../theme/gonordic_theme.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onTap;
  final VoidCallback onShowBoardingPass;
  final VoidCallback? onCheckIn;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onTap,
    required this.onShowBoardingPass,
    this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    final isCheckedIn = booking.isCheckedIn;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCheckedIn ? GoNordicTheme.success : GoNordicTheme.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: GoNordicTheme.pine.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking.pnr,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: GoNordicTheme.pine,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCheckedIn ? const Color(0xFFDCFCE7) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCheckedIn ? tr('widgets.bookingCard.checkedIn') : tr('widgets.bookingCard.confirmed'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isCheckedIn ? GoNordicTheme.success : const Color(0xFF0369A1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                booking.routeName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: GoNordicTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: GoNordicTheme.teal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr('widgets.bookingCard.departure', {'date': booking.departureDate, 'time': booking.departureTime}),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: GoNordicTheme.teal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    booking.vesselName,
                    style: const TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onShowBoardingPass,
                      icon: const Icon(Icons.qr_code, size: 18),
                      label: Text(tr('widgets.bookingCard.showBoardingPass')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GoNordicTheme.pine,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (!isCheckedIn && onCheckIn != null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onCheckIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GoNordicTheme.lime,
                        foregroundColor: GoNordicTheme.pineDark,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(tr('widgets.bookingCard.checkIn')),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
