import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/payments/presentation/dashboard_page.dart';
import 'theme.dart';

class LedgerStreamApp extends ConsumerWidget {
  const LedgerStreamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'LedgerStream',
      theme: buildLightTheme(),
      debugShowCheckedModeBanner: false,
      home: const DashboardPage(),
    );
  }
}
