class OriginDebugContentTemplate {
  const OriginDebugContentTemplate({
    required this.name,
    required this.worldView,
    required this.worldLogic,
    required this.firstCharacterName,
    required this.firstCharacterIdentity,
    required this.firstCharacterBio,
    required this.firstCharacterGoal,
    required this.secondCharacterName,
    required this.secondCharacterIdentity,
    required this.secondCharacterBio,
    required this.secondCharacterGoal,
    required this.regions,
    required this.openingNarration,
    required this.openingDialogue,
    required this.storyEvents,
  });

  final String name;
  final String worldView;
  final String worldLogic;
  final String firstCharacterName;
  final String firstCharacterIdentity;
  final String firstCharacterBio;
  final String firstCharacterGoal;
  final String secondCharacterName;
  final String secondCharacterIdentity;
  final String secondCharacterBio;
  final String secondCharacterGoal;
  final List<OriginDebugRegionTemplate> regions;
  final String openingNarration;
  final String openingDialogue;
  final List<String> storyEvents;
}

class OriginDebugRegionTemplate {
  const OriginDebugRegionTemplate({
    required this.name,
    required this.districts,
  });

  final String name;
  final List<OriginDebugDistrictTemplate> districts;
}

class OriginDebugDistrictTemplate {
  const OriginDebugDistrictTemplate({
    required this.name,
    required this.locations,
  });

  final String name;
  final List<OriginDebugLocationTemplate> locations;
}

class OriginDebugLocationTemplate {
  const OriginDebugLocationTemplate({
    required this.name,
    required this.description,
    required this.imageKeywords,
  });

  final String name;
  final String description;
  final String imageKeywords;
}
