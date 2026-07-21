import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'powersync/schema.dart';
import 'powersync/connector.dart';
import 'db/database_helper.dart';
import 'screens/sales_counter_screen.dart';

late PowerSyncDatabase powerSyncDb;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationSupportDirectory();
  final dbPath = p.join(dir.path, 'hardware_pos_powersync.db');

  powerSyncDb = PowerSyncDatabase(schema: schema, path: dbPath);
  await powerSyncDb.initialize();

  // Connect to PowerSync in the background. If offline, this fails
  // silently and retries automatically — the app still works fully
  // offline using the local SQLite file above.
  powerSyncDb.connect(connector: HardwarePosConnector(powerSyncDb));

  // Make sure a default inventory password exists on first run.
  await DatabaseHelper.instance.ensureDefaultPassword();

  runApp(const ProviderScope(child: HardwarePosApp()));
}

class HardwarePosApp extends StatelessWidget {
  const HardwarePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hardware POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F7F5),
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          surface: Color(0xFFF7F7F5),
          onSurface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        fontFamily: 'Roboto',
      ),
      home: const SalesCounterScreen(),
    );
  }
}