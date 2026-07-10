import '../models/gem_home.dart';
import '../models/gem_wallet.dart';
import 'v1_api_resource.dart';

class GemV1Api extends V1ApiResource {
  const GemV1Api(super.client);

  /// GET /api/v1/gem/home
  Future<GemHome> home() async {
    return GemHome.fromJson(await getMap('gem/home'));
  }

  /// GET /api/v1/gem/wallet
  Future<GemWallet> wallet() async {
    return GemWallet.fromJson(await getMap('gem/wallet'));
  }
}
