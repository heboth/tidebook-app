class CabinModel {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final String description;
  final double priceDkk;
  final int maxGuests;
  final String imageAsset;
  final int deckNumber;
  final List<String> highlights;
  final bool includesBreakfast;

  const CabinModel({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.priceDkk,
    required this.maxGuests,
    required this.imageAsset,
    required this.deckNumber,
    required this.highlights,
    this.includesBreakfast = false,
  });

  static List<CabinModel> get defaultCabins => [
    const CabinModel(
      id: 'CAB-COMM-BALC',
      category: 'COMMODORE_BALCONY',
      title: 'Commodore Balcony',
      subtitle: 'Luksuskahyt med privat balkon',
      description: 'Nyd den friske havbrise og panoramaudsigt fra din egen private altan. Inkluderer luksusmorgenmad og VIP lounge adgang.',
      priceDkk: 1890,
      maxGuests: 2,
      imageAsset: 'assets/gonordic/images/cabin-commodore-balcony.jpg',
      deckNumber: 11,
      highlights: ['Privat balkon', 'Inkl. morgenmadsbuffet', 'Commodore Lounge', 'Dobbeltseng', 'Minibar'],
      includesBreakfast: true,
    ),
    const CabinModel(
      id: 'CAB-COMM-DELUXE',
      category: 'COMMODORE_DELUXE',
      title: 'Commodore de Luxe',
      subtitle: 'Eksklusiv kahyt med havudsigt',
      description: 'Rummelig luksuskahyt med dobbeltseng, skrivebord, minibar og store havudsigtsvinduer. Inkl. gratis morgenmadsbuffet.',
      priceDkk: 1450,
      maxGuests: 2,
      imageAsset: 'assets/gonordic/images/cabin-commodore-deluxe.jpg',
      deckNumber: 9,
      highlights: ['Havudsigt', 'Inkl. morgenmad', 'Dobbeltseng', 'Minibar', 'Commodore Lounge'],
      includesBreakfast: true,
    ),
    const CabinModel(
      id: 'CAB-COMM-SEAVIEW',
      category: 'COMMODORE_SEAVIEW',
      title: 'Commodore Havudsigt',
      subtitle: 'Premium komfort for par',
      description: 'Klassisk Commodore kahyt med store vinduer mod Oslofjorden, komfortable senge og fri adgang til Commodore Lounge.',
      priceDkk: 1190,
      maxGuests: 2,
      imageAsset: 'assets/gonordic/images/cabin-commodore-seaview.jpg',
      deckNumber: 9,
      highlights: ['Havudsigt', 'Dobbeltseng', 'Lounge adgang', 'TV & Wi-Fi'],
      includesBreakfast: true,
    ),
    const CabinModel(
      id: 'CAB-STD-SEAVIEW',
      category: 'STANDARD_SEAVIEW',
      title: 'Standard Udvendig',
      subtitle: 'Havudsigt til overkommelig pris',
      description: 'Behagelig kahyt med vindue mod havet, eget badeværelse, enkeltsenge og behagelige dyner for en god nats søvn.',
      priceDkk: 650,
      maxGuests: 4,
      imageAsset: 'assets/gonordic/images/cabin-standard-seaview.jpg',
      deckNumber: 7,
      highlights: ['Vindue mod havet', 'Eget bad & toilet', '2-4 køjesenge'],
    ),
    const CabinModel(
      id: 'CAB-STD-INSIDE',
      category: 'STANDARD_INSIDE',
      title: 'Standard Indvendig',
      subtitle: 'Klassisk og rolig kahyt',
      description: 'Vores populære og rolige standardkahyt med eget badeværelse og behagelige køjesenge. Perfekt til par og familier.',
      priceDkk: 450,
      maxGuests: 4,
      imageAsset: 'assets/gonordic/images/cabin-standard-inside.jpg',
      deckNumber: 7,
      highlights: ['Rolig beliggenhed', 'Eget bad & toilet', 'God værdi'],
    ),
    const CabinModel(
      id: 'CAB-ECON-INSIDE',
      category: 'ECONOMY_INSIDE',
      title: 'Economy Indvendig',
      subtitle: 'Budgetvenlig overfart',
      description: 'Vores mest prisvenlige kahytstype. Simpel, ren og funktionel med eget bad for de rejsende der ønsker den bedste pris.',
      priceDkk: 290,
      maxGuests: 2,
      imageAsset: 'assets/gonordic/images/cabin-economy-inside.jpg',
      deckNumber: 5,
      highlights: ['Laveste pris', 'Eget bad', 'Køjesenge'],
    ),
    const CabinModel(
      id: 'CAB-FAMILY',
      category: 'FAMILY',
      title: 'Familiekahyt Udvendig',
      subtitle: 'Ekstra plads til hele familien',
      description: 'Stor familievenlig kahyt med vindue, plads til op til 5 personer og mulighed for babyseng. Tæt på børneområde.',
      priceDkk: 850,
      maxGuests: 5,
      imageAsset: 'assets/gonordic/images/cabin-family.jpg',
      deckNumber: 6,
      highlights: ['Op til 5 personer', 'Vindue', 'Familievenlig placering'],
    ),
    const CabinModel(
      id: 'CAB-OWNER-SUITE',
      category: 'OWNERS_SUITE',
      title: "Owner's Luxury Suite",
      subtitle: 'Det ypperste inden for luksus',
      description: 'Skibets mest eksklusive suite på toppen af færgen med separat stue, jacuzzi, stor privat tagterrasse og butler service.',
      priceDkk: 3450,
      maxGuests: 4,
      imageAsset: 'assets/gonordic/images/cabin-owners-suite.jpg',
      deckNumber: 11,
      highlights: ['Privat tagterrasse', 'Jacuzzi', 'Separat stue', 'VIP Lounge & Bar'],
      includesBreakfast: true,
    ),
  ];
}
