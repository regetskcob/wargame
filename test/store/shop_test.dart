import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/ui/theme.dart';
import 'package:wargame/src/store/product.dart';
import 'package:wargame/src/store/shop.dart';
import 'package:wargame/src/ui/widgets/supporter_section.dart';

class _Store implements StoreGateway {
  final updates = StreamController<List<StorePurchase>>.broadcast();
  final bought = <Product>[];
  final finished = <StorePurchase>[];
  var restored = 0;
  var open = true;

  @override
  String get store => 'app_store';

  @override
  Future<bool> available() async => open;

  @override
  Future<List<Offer>> offers(Set<Product> products) async => [
    for (final product in products) Offer(product: product, price: '2,99 €'),
  ];

  @override
  Future<void> buy(Product product) async => bought.add(product);

  @override
  Future<void> restore() async => restored++;

  @override
  Stream<List<StorePurchase>> get purchases => updates.stream;

  @override
  Future<void> finish(StorePurchase purchase) async => finished.add(purchase);
}

class _Server implements PurchaseServer {
  var accepts = true;
  var owns = <Product>{};
  final checked = <StorePurchase>[];

  @override
  Future<bool> verify(String store, StorePurchase purchase) async {
    checked.add(purchase);
    return accepts;
  }

  @override
  Future<Set<Product>> owned() async => owns;
}

StorePurchase _purchase({
  bool pending = false,
  bool canceled = false,
  bool restored = false,
}) => StorePurchase(
  product: Product.supporter,
  transactionId: '2000000123',
  proof: 'jws',
  pending: pending,
  canceled: canceled,
  restored: restored,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Store store;
  late _Server server;
  var signedIn = true;
  Shop shop() => Shop(gateway: store, server: server, signedIn: () => signedIn);

  setUp(() {
    store = _Store();
    server = _Server();
    signedIn = true;
  });

  Future<void> deliver(StorePurchase purchase) async {
    store.updates.add([purchase]);
    await pumpEventQueue();
  }

  test(
    'opens with the store\'s offers and reads what the account owns',
    () async {
      server.owns = {Product.supporter};
      final s = shop();
      await s.start();
      expect(s.open.value, isTrue);
      expect(s.offers.value.single.price, '2,99 €');
      expect(s.owns(Product.supporter), isTrue);
    },
  );

  test('a closed shop sells nothing but still knows what was bought', () async {
    server.owns = {Product.supporter};
    final s = Shop.closed(server: server, signedIn: () => true);
    await s.start();
    expect(s.open.value, isFalse);
    expect(s.owns(Product.supporter), isTrue);
  });

  test('no store on the device keeps the shop shut', () async {
    store.open = false;
    final s = shop();
    await s.start();
    expect(s.open.value, isFalse);
  });

  test('a guest can neither buy nor restore', () async {
    signedIn = false;
    final s = shop();
    await s.start();
    await s.buy(Product.supporter);
    await s.restore();
    expect(store.bought, isEmpty);
    expect(store.restored, 0);
    expect(s.message.value, contains('Konto'));
    expect(s.owned.value, isEmpty);
  });

  test('a purchase the server confirms counts and is finished', () async {
    final s = shop();
    await s.start();
    await s.buy(Product.supporter);
    expect(s.busy.value, isTrue);
    await deliver(_purchase());
    expect(server.checked, hasLength(1));
    expect(s.owns(Product.supporter), isTrue);
    expect(store.finished, hasLength(1));
    expect(s.busy.value, isFalse);
  });

  test('a purchase the server refuses stays open in the store', () async {
    server.accepts = false;
    final s = shop();
    await s.start();
    await deliver(_purchase());
    expect(s.owns(Product.supporter), isFalse);
    expect(store.finished, isEmpty);
    expect(s.message.value, isNotNull);
  });

  test('a purchase made while signed out waits for an account', () async {
    final s = shop();
    await s.start();
    signedIn = false;
    await deliver(_purchase());
    expect(server.checked, isEmpty);
    expect(store.finished, isEmpty);
  });

  test('cancelled says nothing, pending waits', () async {
    final s = shop();
    await s.start();
    await deliver(_purchase(canceled: true));
    expect(s.message.value, isNull);
    expect(store.finished, hasLength(1));
    await deliver(_purchase(pending: true));
    expect(s.message.value, isNotNull);
    expect(server.checked, isEmpty);
  });

  test('signing out forgets what the account owns', () async {
    server.owns = {Product.supporter};
    final s = shop();
    await s.start();
    signedIn = false;
    await s.refresh();
    expect(s.owned.value, isEmpty);
  });

  group('section', () {
    Future<void> pump(WidgetTester tester, Shop s, {required bool guest}) =>
        tester.pumpWidget(
          MaterialApp(
            theme: buildGameTheme(),
            home: Scaffold(
              body: SupporterSection(shop: s, guest: guest),
            ),
          ),
        );

    testWidgets('a guest sees the offer but cannot buy', (tester) async {
      final s = shop();
      await s.start();
      await pump(tester, s, guest: true);
      expect(find.textContaining('2,99 €'), findsOneWidget);
      expect(find.textContaining('nur mit Konto'), findsOneWidget);
      final buy = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(buy.onPressed, isNull);
    });

    testWidgets('an account buys with one tap', (tester) async {
      final s = shop();
      await s.start();
      await pump(tester, s, guest: false);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(store.bought, [Product.supporter]);
    });

    testWidgets('after buying it thanks and offers no second purchase', (
      tester,
    ) async {
      server.owns = {Product.supporter};
      final s = shop();
      await s.start();
      await pump(tester, s, guest: false);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.textContaining('Danke'), findsOneWidget);
    });
  });
}
