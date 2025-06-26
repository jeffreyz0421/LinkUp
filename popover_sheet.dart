import 'package:flutter/material.dart';
import 'models.dart';

void showBuildingSheet({
  required BuildContext ctx,
  required Building building,
  required ValueChanged<Space> onSelect,
}) {
  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: 0.76,
          child: _Sheet(building: building, onSelect: onSelect),
        ),
      );
    },
  );
}

class _Sheet extends StatelessWidget {
  final Building building;
  final ValueChanged<Space> onSelect;

  const _Sheet({required this.building, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: building.spaces
            .map((space) => ListTile(
                  title: Text(space.name),
                  onTap: () => onSelect(space),
                ))
            .toList(),
      ),
    );
  }
}
