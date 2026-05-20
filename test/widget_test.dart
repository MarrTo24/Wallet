import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:identity_wallet_mvp/app/app.dart';

void main() {
  testWidgets('shows splash title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: IdentityWalletApp()));

    expect(find.text('Identity Wallet'), findsOneWidget);
  });
}
