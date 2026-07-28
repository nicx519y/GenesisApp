import '../api_client.dart';
import 'origin_api.dart';

class GenesisV2Api {
  GenesisV2Api(ApiClient client) : origin = OriginV2Api(client);

  final OriginV2Api origin;
}
