import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class IdentityWalletApp extends StatelessWidget {
  const IdentityWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Identity Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
