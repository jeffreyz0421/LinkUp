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

class _Sheet extends StatefulWidget {
  final Building building;
  final ValueChanged<Space> onSelect;
  const _Sheet({required this.building, required this.onSelect});

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = query.isEmpty
        ? widget.building.spaces
        : widget.building.spaces
            .where((s) =>
                s.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.building.name,
                style: const TextStyle(
                    fontFamily: 'ChalkboardSE-Bold',
                    fontSize: 18,
                    color: Colors.white),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.indigo.shade700,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(widget.building.funFact,
                  style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search spaces…',
                filled: true,
                fillColor: Colors.white,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => query = v),
              onSubmitted: (v) {
                if (filtered.isNotEmpty) widget.onSelect(filtered.first);
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                children: filtered
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                primary: Colors.yellow.shade700,
                                onPrimary: Colors.indigo,
                                padding: const EdgeInsets.all(12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            onPressed: () => widget.onSelect(s),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name,
                                      style: const TextStyle(
                                          fontFamily: 'ChalkboardSE-Bold')),
                                  Text(s.subtitle,
                                      style: const TextStyle(fontSize: 12))
                                ]),
                          ),
                        ))
                    .toList(),
              ),
            )
          ],
        ),
      ),
    );
  }
}
