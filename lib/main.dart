import 'package:flutter/material.dart';
import 'package:flutter_social/pages/home.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlutterSocial',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        accentColor: Colors.teal
      ),
      home: Home(),
    );
  }
}