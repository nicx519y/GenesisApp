import 'package:genesis_flutter_android/network/models/personalization.dart';

Map<String, dynamic> personalizationJson({
  bool completed = false,
  int genders = 5,
  int ages = 7,
}) => {
  'gender': completed ? 'g0' : '',
  'age': completed ? 'a0' : '',
  'completed': completed,
  'form': [
    {
      'name': 'gender',
      'label': 'Gender',
      'required': true,
      'options': [
        for (var i = 0; i < genders; i++)
          {'value': 'g$i', 'label': 'Gender $i'},
      ],
    },
    {
      'name': 'age',
      'label': 'Age',
      'required': true,
      'options': [
        for (var i = 0; i < ages; i++) {'value': 'a$i', 'label': 'Age $i'},
      ],
    },
  ],
};

PersonalizationData personalizationData({
  bool completed = false,
  int genders = 5,
  int ages = 7,
}) => PersonalizationData.fromJson(
  personalizationJson(completed: completed, genders: genders, ages: ages),
);
