class SwipeItem {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final List<String> tags; // Surface level tags for display
  final List<double> vector; // The 10-dimensional semantic vector

  const SwipeItem({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.tags,
    required this.vector,
  });

  // Factory for creation from JSON if needed later
  factory SwipeItem.fromJson(Map<String, dynamic> json) {
    return SwipeItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      tags: List<String>.from(json['tags']),
      vector: List<double>.from(json['vector']),
    );
  }
}
