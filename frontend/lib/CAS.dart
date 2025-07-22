import 'package:flutter/material.dart';
import 'meetup.dart';
import 'pullup.dart';
import 'linkup.dart';
import 'main_screen_ui.dart';

class CASScreen extends StatelessWidget {
  const CASScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create A Social'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MapScreen()),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCASButton(
              context,
              label: 'Meetup',
              color: Colors.lightBlue.shade100,
              target: const MeetupScreen(),
            ),
            const SizedBox(height: 24),
            _buildCASButton(
              context,
              label: 'Pullup',
              color: Colors.green.shade100,
              target: const PullupScreen(),
            ),
            const SizedBox(height: 24),
            _buildCASButton(
              context,
              label: 'Linkup',
              color: Colors.purple.shade100,
              target: const LinkupScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCASButton(BuildContext context, {required String label, required Color color, required Widget target}) {
    return SizedBox(
      width: double.infinity,
      height: 100,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => target),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 4,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
    );
  }
}
