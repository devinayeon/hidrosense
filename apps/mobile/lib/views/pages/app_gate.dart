import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/session_viewmodel.dart';
import 'login_page.dart';
import 'main_page.dart';

class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((state) => state.user));

    return Navigator(
      key: ValueKey(user?.id),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => user == null ? const LoginPage() : const MainPage(),
      ),
    );
  }
}
