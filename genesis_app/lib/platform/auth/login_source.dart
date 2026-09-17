/// Entry that initiated authentication; captured before provider UI opens.
enum LoginSource {
  unknown('from_unknown'),
  home('from_home'),
  me('from_me'),
  personalization('from_personalization'),
  membershipClaim('from_membership_claim'),
  createWorldo('from_create_worldo'),
  editWorldo('from_edit_worldo'),
  messages('from_messages'),
  profile('from_profile'),
  follows('from_follows'),
  discuss('from_discuss'),
  privateChat('from_private_chat'),
  locationChat('from_location_chat'),
  worldoDetail('from_worldo_detail'),
  worldDetail('from_world_detail');

  const LoginSource(this.value);
  final String value;
}
