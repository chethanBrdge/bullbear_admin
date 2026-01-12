import 'package:flutter/material.dart';
import 'routes/app_routes.dart';
import 'utils/theme.dart';
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter,
      title: 'BullBear Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,  
    );
  }
}
