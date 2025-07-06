import 'package:flutter/material.dart';
import 'models.dart';

void showBuildingSheet({
  required BuildContext ctx,
  required Building building,
  required void Function(Space s) onSelect,
}) {
  showModalBottomSheet(
    context: ctx,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => _Sheet(building: building, onSelect: onSelect),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.building, required this.onSelect});
  final Building building;
  final void Function(Space) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(building.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ...building.spaces.map(
          (s) => ListTile(
            title: Text(s.name),
            onTap: () => onSelect(s),
          ),
        ),
      ],
    );
  }
}

class DestinationPage extends StatelessWidget {
  const DestinationPage({Key? key, required this.label}) : super(key: key);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(label),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to $label',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}