/// Shared mock profile construction; used by normal submission and QA fixtures.
Map<String, Object?> completedMockPersonalization(
  String gender,
  String age, [
  Map<String, Object?>? existing,
]) {
  if (!const ['Male', 'Female', 'Non_binary'].contains(gender) ||
      !const ['18-24', '25-34', '35-44', '45+'].contains(age)) {
    throw ArgumentError('Invalid mock personalization choices');
  }
  return {
    'gender': gender,
    'age': age,
    'origin_feed_gender':
        (existing?['origin_feed_gender'] as String?)?.isNotEmpty == true
        ? existing!['origin_feed_gender']
        : switch (gender) {
            'Male' => 'Female',
            'Female' => 'Male',
            _ => 'Non_binary',
          },
    'completed': true,
  };
}
