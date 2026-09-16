class PersonalizationProfile {
  const PersonalizationProfile({
    this.gender,
    this.age,
    this.originFeedGender,
    this.completed = false,
  });

  factory PersonalizationProfile.fromJson(Map<String, dynamic> json) {
    final gender = json['gender'];
    final age = json['age'];
    final completed = json['completed'];
    final originFeedGender = json['origin_feed_gender'];
    if (gender is! String ||
        age is! String ||
        completed is! bool ||
        !const {
          '',
          'Male',
          'Female',
          'Non_binary',
          'All',
        }.contains(originFeedGender) ||
        completed && (gender.isEmpty || age.isEmpty)) {
      throw const FormatException('Invalid personalization profile');
    }
    return PersonalizationProfile(
      gender: gender.isEmpty ? null : gender,
      age: age.isEmpty ? null : age,
      completed: completed,
      originFeedGender: originFeedGender == ''
          ? null
          : originFeedGender as String,
    );
  }

  final String? gender;
  final String? age;

  /// Server-owned feed preference. Null is unset; All is an explicit choice.
  final String? originFeedGender;
  final bool completed;
  bool get isComplete => gender != null && age != null;
  Map<String, Object?> toJson() => {'gender': gender, 'age': age};
}

class PersonalizationOption {
  const PersonalizationOption({required this.value, required this.label});
  final String value;
  final String label;
}

class PersonalizationField {
  const PersonalizationField({
    required this.name,
    required this.label,
    required this.options,
  });
  final String name;
  final String label;
  final List<PersonalizationOption> options;

  factory PersonalizationField.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final label = json['label'];
    final options = json['options'];
    if (!const ['gender', 'age'].contains(name) ||
        label is! String ||
        json['required'] != true ||
        options is! List) {
      throw const FormatException('Invalid personalization field');
    }
    final seen = <String>{};
    return PersonalizationField(
      name: name as String,
      label: label,
      options: List.unmodifiable(
        options.map((option) {
          if (option is! Map ||
              option['value'] is! String ||
              (option['value'] as String).isEmpty ||
              option['label'] is! String ||
              !seen.add(option['value'] as String)) {
            throw const FormatException('Invalid personalization option');
          }
          return PersonalizationOption(
            value: option['value'] as String,
            label: option['label'] as String,
          );
        }),
      ),
    );
  }
}

class PersonalizationData {
  const PersonalizationData({required this.profile, required this.form});
  final PersonalizationProfile profile;
  final List<PersonalizationField> form;

  factory PersonalizationData.fromJson(Map<String, dynamic> json) {
    final form = json['form'];
    if (form is! List) {
      throw const FormatException('Missing personalization form');
    }
    final fields = form
        .map((value) {
          if (value is! Map<String, dynamic>) {
            throw const FormatException('Invalid personalization form');
          }
          return PersonalizationField.fromJson(value);
        })
        .toList(growable: false);
    if (fields.length != 2 || fields.map((f) => f.name).toSet().length != 2) {
      throw const FormatException('Missing personalization fields');
    }
    return PersonalizationData(
      profile: PersonalizationProfile.fromJson(json),
      form: List.unmodifiable(fields),
    );
  }

  bool accepts(PersonalizationProfile value) =>
      value.isComplete &&
      form.every((field) {
        final selected = field.name == 'gender' ? value.gender : value.age;
        return field.options.any((option) => option.value == selected);
      });
}
