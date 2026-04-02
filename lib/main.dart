import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MilkApp());
}

class MilkApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Milk Delivery App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}