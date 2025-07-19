//meetup.dart

import 'package:flutter/material.dart';

class MeetupScreen extends StatelessWidget {
  const MeetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meetup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text('This is the Meetup screen'),
      ),
    );
  }
}
