import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../services/texts_service.dart';
import '../theme/gonordic_theme.dart';
import '../widgets/maritime_qr_widget.dart';

class BoardingPassScreen extends StatefulWidget {
  final BookingModel booking;
  const BoardingPassScreen({super.key, required this.booking});

  @override
  State<BoardingPassScreen> createState() => _BoardingPassScreenState();
}

class _BoardingPassScreenState extends State<BoardingPassScreen> {
  late BookingModel _booking;
  int _selectedPaxIndex = 0;
  bool _isCheckingIn = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  Future<void> _performCheckIn() async {
    setState(() => _isCheckingIn = true);
    final result = await BookingService().checkInBookingWithResult(_booking.pnr);
    setState(() => _isCheckingIn = false);

    if (!mounted) return;
    if (result.success && result.booking != null) {
      setState(() {
        _booking = result.booking!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GoNordicTheme.success,
          content: Text(tr('boardingPass.checkInDone')),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GoNordicTheme.error,
          content: Text(result.errorMessage ?? tr('boardingPass.checkInFailed')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final passes = _booking.boardingPasses;
    final hasPasses = passes.isNotEmpty;
    final currentPass = hasPasses
        ? (_selectedPaxIndex < passes.length ? passes[_selectedPaxIndex] : passes.first)
        : null;

    final leadPax = currentPass?.passengerName ??
        (_booking.passengers.isNotEmpty
            ? _booking.passengers.first.fullName
            : _booking.leadContactName);

    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(title: Text(tr('boardingPass.title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (passes.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(passes.length, (idx) {
                    final isSel = idx == _selectedPaxIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 12),
                      child: ChoiceChip(
                        label: Text(passes[idx].passengerName.split(' ').first),
                        selected: isSel,
                        selectedColor: GoNordicTheme.pine,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : GoNordicTheme.pineDark,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => setState(() => _selectedPaxIndex = idx),
                      ),
                    );
                  }),
                ),
              ),
            ],
            Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/gonordic/logo_white.png',
                      height: 18,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => const SizedBox(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _booking.routeName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _booking.isCheckedIn ? tr('boardingPass.statusCheckedIn') : tr('boardingPass.statusReady'),
                          style: const TextStyle(color: GoNordicTheme.lime, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!hasPasses) ...[
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, size: 48, color: GoNordicTheme.teal),
                      const SizedBox(height: 12),
                      Text(
                        tr('boardingPass.issuedAtCheckIn'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GoNordicTheme.pine),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('boardingPass.issuedAtCheckInBody'),
                        style: const TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isCheckingIn ? null : _performCheckIn,
                        icon: _isCheckingIn
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.how_to_reg),
                        label: Text(_isCheckingIn ? tr('boardingPass.checkingIn') : tr('boardingPass.checkInNow')),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: MaritimeQrWidget(
                    qrPayload: currentPass?.qrPayload ?? '',
                    size: 180,
                  ),
                ),
              ],
              Text(
                _booking.pnr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w900, color: GoNordicTheme.pine),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row(tr('boardingPass.passenger'), leadPax, tr('boardingPass.departure'), '${_booking.departureDate} ${_booking.departureTime}'),
                    const SizedBox(height: 12),
                    _row(tr('boardingPass.ship'), _booking.vesselName, tr('boardingPass.cabin'), currentPass?.seatOrCabin ?? _booking.cabinTitle),
                    const SizedBox(height: 12),
                    _row(tr('boardingPass.gate'), _booking.gateNumber, tr('boardingPass.vehicle'), _booking.vehicle?.licensePlate ?? tr('boardingPass.onFoot')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
