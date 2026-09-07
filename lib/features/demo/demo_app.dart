import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const _lime = Color(0xFFD4F84B);
const _ink = Color(0xFF18231D);

class DemoListing {
  const DemoListing(this.id, this.title, this.category, this.price, this.location,
      this.owner, this.description, this.icon, this.color);
  final int id;
  final String title;
  final String category;
  final int price;
  final String location;
  final String owner;
  final String description;
  final IconData icon;
  final Color color;
}

const demoListings = [
  DemoListing(1, 'Canon EOS R6 камер', 'Камер', 85000, 'Сүхбаатар дүүрэг', 'Бат',
      '24–105 мм дуран, хоёр батарей, 128 GB карт, цүнхтэй. Аялал болон зураг авалтад тохиромжтой.',
      Icons.photo_camera_outlined, Color(0xFFE9E5DC)),
  DemoListing(2, 'DJI Mini 4 Pro дрон', 'Дрон', 120000, 'Хан-Уул дүүрэг', 'Саруул',
      'Удирдлага, гурван батарей, цэнэглэгчтэй иж бүрдэл. Зөвшөөрөгдсөн орчинд нисгэнэ.',
      Icons.flight_outlined, Color(0xFFE0EAE8)),
  DemoListing(3, 'PlayStation 5 иж бүрдэл', 'Тоглоом', 45000, 'Баянгол дүүрэг', 'Тэмүүлэн',
      'Хоёр удирдлагатай. Найзуудтайгаа амралтын өдрийг өнгөрүүлэхэд тохиромжтой.',
      Icons.sports_esports_outlined, Color(0xFFE5E1F1)),
  DemoListing(4, '4 хүний аяллын майхан', 'Аялал', 25000, 'Баянзүрх дүүрэг', 'Номин',
      'Усны хамгаалалттай, угсрахад хялбар. Гадас, татлага, зөөврийн ууттай.',
      Icons.holiday_village_outlined, Color(0xFFE4EDD6)),
  DemoListing(5, 'Bosch өрөмний багц', 'Багаж', 20000, 'Сонгинохайрхан дүүрэг', 'Эрдэнэ',
      'Цэнэглэдэг өрөм, хоёр батарей, хошууны багцтай. Гэрийн жижиг засварт ашиглана.',
      Icons.handyman_outlined, Color(0xFFF0E4D5)),
  DemoListing(6, 'JBL PartyBox чанга яригч', 'Аудио', 60000, 'Чингэлтэй дүүрэг', 'Ану',
      'Bluetooth холболттой, микрофонтой. Жижиг арга хэмжээ, төрсөн өдөрт тохиромжтой.',
      Icons.speaker_outlined, Color(0xFFE9DEF0)),
  DemoListing(7, 'Full HD проектор', 'Электроник', 55000, 'Хан-Уул дүүрэг', 'Мөнх',
      'HDMI кабель, удирдлага, зөөврийн дэлгэцтэй. Танилцуулга болон кино үзэхэд ашиглана.',
      Icons.videocam_outlined, Color(0xFFDCE8F0)),
  DemoListing(8, 'Уулын дугуй', 'Спорт', 30000, 'Сүхбаатар дүүрэг', 'Туул',
      '27.5 инчийн дугуй, хамгаалалтын малгай, цоожтой. Хот болон хөнгөн замд унахад бэлэн.',
      Icons.pedal_bike_outlined, Color(0xFFF1E5DF)),
];

String _money(int amount) => '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} ₮';

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ХУВААЛЦ • Демо',
    debugShowCheckedModeBanner: false,
    locale: const Locale('mn'),
    supportedLocales: const [Locale('mn')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _ink, primary: _ink, secondary: _lime),
      scaffoldBackgroundColor: const Color(0xFFFAFAF6),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFFAFAF6), foregroundColor: _ink),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: _lime, foregroundColor: _ink,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      )),
    ),
    home: const DemoWelcome(),
  );
}

class DemoWelcome extends StatelessWidget {
  const DemoWelcome({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.interests_outlined, size: 64, color: _ink),
          const SizedBox(height: 28),
          const Text('ХУВААЛЦ', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 16),
          const Text('Хэрэгтэй зүйлээ\nтүрээслээд хэрэглэ.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2)),
          const SizedBox(height: 20),
          const Text('Камер, аяллын хэрэгсэл, тоглоом, багаж гээд өдөр бүр хэрэггүй ч заримдаа хэрэг болдог бүхнийг нэг дор.', style: TextStyle(fontSize: 16, height: 1.6)),
          const SizedBox(height: 32),
          FilledButton(key: const Key('enter-demo'), onPressed: () {
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DemoHome()));
          }, child: const Text('Демо үзэх')),
          const SizedBox(height: 16),
          const Text('Интернэт, утасны дугаар, бүртгэл шаардахгүй. Бүх зар болон захиалга жишээ өгөгдөл. Демо горимоос гарахад өөрчлөлтүүд арилна.', style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black54)),
        ],
      )),
    ))),
  );
}

class _DemoOrder {
  const _DemoOrder(this.listing, this.days);
  final DemoListing listing;
  final int days;
}

class DemoHome extends StatefulWidget {
  const DemoHome({super.key});
  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  int _tab = 0;
  String _query = '';
  String _category = 'Бүгд';
  final Set<int> _saved = {};
  final List<_DemoOrder> _orders = [];

  Future<void> _open(DemoListing listing) async {
    final days = await Navigator.of(context).push<int>(MaterialPageRoute<int>(
      builder: (_) => DemoDetail(listing: listing),
    ));
    if (!mounted || days == null) return;
    setState(() { _orders.add(_DemoOrder(listing, days)); _tab = 2; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Демо захиалга үүслээ. Төлбөр аваагүй.')));
  }

  @override
  Widget build(BuildContext context) {
    final listings = demoListings.where((item) =>
      (_tab != 1 || _saved.contains(item.id)) &&
      (_tab == 1 || _category == 'Бүгд' || item.category == _category) &&
      (_tab == 1 || '${item.title} ${item.category} ${item.location}'.toLowerCase().contains(_query.toLowerCase().trim())),
    ).toList();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('ХУВААЛЦ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Гарах'))],
      ),
      body: Column(children: [
        Container(width: double.infinity, color: _lime, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: const Text('ДЕМО • Жишээ зарууд • Бодит төлбөргүй', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(child: _tab == 2 ? _bookings() : _tab == 3 ? _profile() : ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_tab == 1 ? 'Хадгалсан зарууд' : 'Өнөөдөр танд\nюу хэрэгтэй вэ?', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            if (_tab == 0) ...[
              TextField(key: const Key('demo-search'), onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(hintText: 'Зар хайх', prefixIcon: const Icon(Icons.search), filled: true,
                  fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
              const SizedBox(height: 12),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                for (final category in ['Бүгд', ...demoListings.map((e) => e.category).toSet()])
                  Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                    label: Text(category), selected: _category == category,
                    selectedColor: _lime, onSelected: (_) => setState(() => _category = category))),
              ])),
              const SizedBox(height: 16),
            ],
            if (listings.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 48), child: Text(
              _tab == 1 ? 'Зар дээрх зүрхийг дарж энд хадгалаарай.' : 'Тохирох зар олдсонгүй. Өөр үгээр хайгаарай.',
              textAlign: TextAlign.center)),
            for (final listing in listings) _card(listing),
          ],
        )),
      ]),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Нүүр'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Хадгалсан'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Захиалга'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Профайл'),
        ]),
    );
  }

  Widget _card(DemoListing listing) => Card(
    margin: const EdgeInsets.only(bottom: 16), clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: () => _open(listing), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(height: 128, color: listing.color, child: Stack(children: [
        Center(child: Icon(listing.icon, size: 66, color: _ink)),
        Positioned(right: 8, top: 8, child: IconButton.filledTonal(
          key: Key('save-${listing.id}'), tooltip: _saved.contains(listing.id) ? 'Хадгалснаас хасах' : 'Зар хадгалах',
          onPressed: () => setState(() { if (!_saved.add(listing.id)) _saved.remove(listing.id); }),
          icon: Icon(_saved.contains(listing.id) ? Icons.favorite : Icons.favorite_border))),
      ])),
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(listing.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(listing.location, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
        Text('${_money(listing.price)} / хоног', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ])),
    ])),
  );

  Widget _bookings() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Демо захиалгууд', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
    const SizedBox(height: 16),
    if (_orders.isEmpty) const Text('Одоогоор захиалга алга. Нүүр хэсгээс зар сонгон туршиж үзээрэй.'),
    for (final order in _orders) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(order.listing.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('${order.days} хоног • ${_money(order.listing.price * order.days)}'),
        const Text('Туршилтын захиалга • Төлбөр аваагүй'),
        TextButton(onPressed: () => setState(() => _orders.remove(order)), child: const Text('Демо захиалга цуцлах')),
      ],
    ))),
  ]);

  Widget _profile() => ListView(padding: const EdgeInsets.all(24), children: [
    const CircleAvatar(radius: 40, backgroundColor: _lime, child: Icon(Icons.person_outline, size: 44, color: _ink)),
    const SizedBox(height: 20),
    const Text('Демо хэрэглэгч', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
    const SizedBox(height: 24),
    ListTile(leading: const Icon(Icons.favorite_border), title: const Text('Хадгалсан зар'), trailing: Text('${_saved.length}')),
    ListTile(leading: const Icon(Icons.receipt_long_outlined), title: const Text('Демо захиалга'), trailing: Text('${_orders.length}')),
    const SizedBox(height: 20),
    const Text('Энэ хувилбар интернэтгүй ажиллана. Зар, эзэмшигч, үнэ нь жишээ. Захиалга илгээгдэхгүй, төлбөр авахгүй. Аппаас гарах эсвэл демог хаахад өөрчлөлтүүд арилна.', style: TextStyle(height: 1.6)),
    const SizedBox(height: 24),
    OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Демо горимоос гарах')),
  ]);
}

class DemoDetail extends StatefulWidget {
  const DemoDetail({required this.listing, super.key});
  final DemoListing listing;
  @override
  State<DemoDetail> createState() => _DemoDetailState();
}

class _DemoDetailState extends State<DemoDetail> {
  int _days = 1;
  @override
  Widget build(BuildContext context) {
    final item = widget.listing;
    return Scaffold(
      appBar: AppBar(title: const Text('Зарын дэлгэрэнгүй')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Container(height: 200, decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(24)),
          child: Icon(item.icon, size: 100, color: _ink)),
        const SizedBox(height: 24),
        Text(item.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('${_money(item.price)} / хоног', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text('${item.location}\nЭзэмшигч: ${item.owner} • Жишээ профайл', style: const TextStyle(height: 1.6)),
        const Divider(height: 32),
        Text(item.description, style: const TextStyle(fontSize: 16, height: 1.6)),
        const SizedBox(height: 24),
        const Text('Түрээслэх хоног', style: TextStyle(fontWeight: FontWeight.w700)),
        Row(children: [
          IconButton(key: const Key('days-minus'), tooltip: 'Хоног хасах', onPressed: _days > 1 ? () => setState(() => _days--) : null, icon: const Icon(Icons.remove_circle_outline)),
          Text('$_days хоног', style: const TextStyle(fontSize: 18)),
          IconButton(key: const Key('days-plus'), tooltip: 'Хоног нэмэх', onPressed: _days < 30 ? () => setState(() => _days++) : null, icon: const Icon(Icons.add_circle_outline)),
        ]),
        Text('Нийт: ${_money(item.price * _days)}', key: const Key('demo-total'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        FilledButton(key: const Key('demo-book'), onPressed: () => Navigator.of(context).pop(_days), child: const Text('Демо захиалга хийх')),
        const SizedBox(height: 12),
        const Text('Туршилтын үйлдэл. Бодит захиалга илгээгдэхгүй, төлбөр авахгүй.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
      ]),
    );
  }
}
