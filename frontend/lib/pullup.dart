import 'package:flutter/material.dart';

class PullupScreen extends StatelessWidget {
  const PullupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pullup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text('This is the Pullup screen'),
      ),
    );
  }
}
