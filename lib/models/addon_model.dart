class AddOnModel {
  final String id;
  final String name;
  final String description;
  final double priceDkk;
  final String category; // MEALS, CONNECTIVITY, PRIORITY, COMFORT
  final String iconName;

  const AddOnModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priceDkk,
    required this.category,
    required this.iconName,
  });

  static List<AddOnModel> get defaultAddOns => [
    const AddOnModel(
      id: 'addon-breakfast',
      name: 'Skandinavisk Morgenmadsbuffet',
      description: 'Friskbagt brød, lune røræg, bacon, frisk frugt, juice og barista-kaffe.',
      priceDkk: 149,
      category: 'MEALS',
      iconName: 'restaurant',
    ),
    const AddOnModel(
      id: 'addon-dinner',
      name: 'Stor 7 Seas Aftenbuffet',
      description: 'Stort overdådigt aftenbord med frisk fisk, skaldyr, varme stege, salatbar og fri øl/vin/vand.',
      priceDkk: 289,
      category: 'MEALS',
      iconName: 'dinner_dining',
    ),
    const AddOnModel(
      id: 'addon-priority',
      name: 'Prioriteret Ombordkørsel (Priority Car)',
      description: 'Kør først om bord og kør først fra borde ved ankomst i havnen. Minimerer ventetid.',
      priceDkk: 180,
      category: 'PRIORITY',
      iconName: 'directions_car',
    ),
    const AddOnModel(
      id: 'addon-wifi',
      name: 'Premium Satellit Wi-Fi',
      description: 'Hurtig og stabil internetforbindelse på havet under hele overfarten for op til 2 enheder.',
      priceDkk: 79,
      category: 'CONNECTIVITY',
      iconName: 'wifi',
    ),
    const AddOnModel(
      id: 'addon-lounge',
      name: 'Commodore VIP Lounge Pass',
      description: 'Eksklusiv lounge med fri kaffe, vin, snacks, rolige arbejdsstationer og fantastisk havudsigt.',
      priceDkk: 195,
      category: 'COMFORT',
      iconName: 'wine_bar',
    ),
  ];
}

class SelectedAddOn {
  final AddOnModel addOn;
  int quantity;

  SelectedAddOn({required this.addOn, this.quantity = 1});

  double get totalPrice => addOn.priceDkk * quantity;
}
