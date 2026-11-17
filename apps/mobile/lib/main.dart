import 'package:material_ui/material_ui.dart';

void main() => runApp(const BmsApp());

class BmsApp extends StatelessWidget {
  const BmsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BMS',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF17616A)),
        home: const Scaffold(
          appBar: BmsAppBar(),
          body: Center(child: Text('BMS mobile — M1 foundation')),
        ),
      );
}

class BmsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BmsAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(title: const Text('BMS'));
}
