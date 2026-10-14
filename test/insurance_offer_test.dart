import 'package:flutter_test/flutter_test.dart';
import 'package:tidebook_app/services/api_service.dart';

// Afbestillingsforsikringen kommer fra Core (TideRMS' tilbud) – appen viser den og sender kun kundens valg.
void main() {
  test('tilbuddet læses fra prisberegningen', () {
    final o = InsuranceOffer.fromJson({
      'code': 'TRYG', 'name': 'Afbestillingsforsikring', 'provider': 'Tryg', 'priceDkk': 70.56, 'priceType': 'PERCENT', 'percent': 6,
      'premiumRefundable': false, 'termsUrl': 'https://www.tryg.dk/'
    });
    expect(o.provider, 'Tryg');
    expect(o.priceDkk, 70.56);
    expect(o.percent, 6);
    expect(o.premiumRefundable, isFalse);
    final fixed = InsuranceOffer.fromJson({'code': 'X', 'name': 'X', 'provider': 'Tryg', 'priceDkk': 177, 'priceType': 'FIXED', 'per': 'PERSON'});
    expect(fixed.per, 'PERSON');
    expect(fixed.percent, isNull);
  });
}
