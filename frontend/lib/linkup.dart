import 'package:flutter/material.dart';

class LinkupScreen extends StatelessWidget {
  const LinkupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linkup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text('This is the Linkup screen'),
      ),
    );
  }
}
