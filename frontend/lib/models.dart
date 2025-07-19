class Building {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final List<Space> spaces;

  String? address; // Add this

  Building({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.spaces,
    this.address,
  });
}


class Space {
  final String name;

  Space({required this.name});
}
