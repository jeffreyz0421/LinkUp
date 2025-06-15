import 'package:google_maps_flutter/google_maps_flutter.dart';

class Space {
  final String name;
  final String subtitle;
  final LatLng coord;
  const Space(this.name, this.subtitle, this.coord);
}

class Building {
  final String name;
  final String funFact;
  final LatLng coord;
  final List<Space> spaces;
  const Building(this.name, this.funFact, this.coord, this.spaces);
}

// ––– sample data (same as SwiftUI) –––
const buildings = <Building>[
  Building(
    "📚 SHAPIRO LIBRARY",
    "Home of Bert’s Café & Design Lab.",
    LatLng(42.2756868, -83.7371811),
    [
      Space("Design Lab", "Prototyping & XR studio",
          LatLng(42.27557, -83.73690)),
      Space("Askwith Media Library", "Over 30 000 films & games",
          LatLng(42.27546, -83.73715)),
      Space("Bert's Café", "Coffee • Bagels • Chill",
          LatLng(42.27533, -83.73705)),
    ],
  ),
  Building(
    "📚 HATCHER LIBRARY",
    "Archive of 8 million+ volumes.",
    LatLng(42.2762445, -83.7382238),
    [
      Space("North Lobby", "Info & exhibits",
          LatLng(42.27629, -83.73830)),
      Space("Graduate Reading Room", "Silent study",
          LatLng(42.27610, -83.73810)),
    ],
  ),
  Building("Ⓜ️ THE DIAG", "Central green where Wolverines hang out.",
      LatLng(42.2770, -83.7382), []),
];
