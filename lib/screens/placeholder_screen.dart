import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Icon(Icons.construction, size: 64, color: Colors.grey),
             SizedBox(height: 20),
             Text('Coming Soon: $title', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
