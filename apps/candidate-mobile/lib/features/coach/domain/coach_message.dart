enum CoachMessageAuthor { candidate, coach }

class CoachMessage {
  const CoachMessage({
    required this.id,
    required this.author,
    required this.text,
  });

  final String id;
  final CoachMessageAuthor author;
  final String text;

  Map<String, Object?> toJson() => {
    'id': id,
    'author': author.name,
    'text': text,
  };

  factory CoachMessage.fromJson(Map<String, Object?> json) {
    return CoachMessage(
      id: json['id']! as String,
      author: CoachMessageAuthor.values.byName(json['author']! as String),
      text: json['text']! as String,
    );
  }
}
