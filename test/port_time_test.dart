import 'package:flutter_test/flutter_test.dart';
import 'package:tidebook_app/utils/port_time.dart';

// Afgangstider i havnens tid (Europe/Copenhagen), uanset telefonens tidszone.
void main() {
  test('sommertid og vintertid', () {
    expect(portClock(DateTime.utc(2026, 10, 14, 14, 30)), '16:30'); // CEST
    expect(portClock(DateTime.utc(2027, 1, 11, 15, 30)), '16:30'); // CET
    expect(portIsoDate(DateTime.utc(2027, 1, 11, 23, 30)), '2027-01-12');
  });

  test('skiftet sidste søndag i marts og oktober kl. 01:00 UTC', () {
    expect(portClock(DateTime.utc(2027, 3, 28, 0, 59)), '01:59'); // stadig vintertid
    expect(portClock(DateTime.utc(2027, 3, 28, 1, 0)), '03:00'); // sommertid
    expect(portClock(DateTime.utc(2026, 10, 25, 0, 59)), '02:59'); // stadig sommertid
    expect(portClock(DateTime.utc(2026, 10, 25, 1, 0)), '02:00'); // vintertid
  });
}
