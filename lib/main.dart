import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/family_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FamilyTreeApp());
}

class FamilyTreeApp extends StatelessWidget {
  const FamilyTreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FamilyProvider()..loadData()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Silsilah Keluarga',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1A237E),
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: const Color(0xFFF0F2F8),
              fontFamily: 'Roboto',
              appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF7986CB),
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF121212),
              fontFamily: 'Roboto',
              appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false),
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}