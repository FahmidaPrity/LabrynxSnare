import 'package:flutter/material.dart';
import 'home.dart';

void main() {
  runApp(const LabrynxSnare());
}

class LabrynxSnare extends StatelessWidget {
  const LabrynxSnare({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LabrynxSnare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomePage(),
    );
  }
}
