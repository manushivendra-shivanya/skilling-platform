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
}
