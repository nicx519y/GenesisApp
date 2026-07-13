import '../models/gem_product.dart';
import '../models/gem_purchase_report.dart';
import '../models/gem_records.dart';
import '../models/gem_task.dart';
import '../models/gem_task_action.dart';
import '../models/gem_wallet.dart';
import 'v1_api_resource.dart';

class GemV1Api extends V1ApiResource {
  const GemV1Api(super.client);

  /// GET /api/v1/gem/products
  Future<GemProductList> products() async {
    return GemProductList.fromJson(await getMap('gem/products'));
  }

  /// GET /api/v1/gem/tasks
  Future<GemTaskList> tasks() async {
    return GemTaskList.fromJson(await getMap('gem/tasks'));
  }

  /// GET /api/v1/gem/wallet
  Future<GemWallet> wallet() async {
    return GemWallet.fromJson(await getMap('gem/wallet'));
  }

  /// GET /api/v1/gem/records
  Future<GemRecordList> records({
    String scene = 'all',
    int pn = 1,
    int rn = 20,
  }) async {
    return GemRecordList.fromJson(
      await getMap(
        'gem/records',
        v1Query({'scene': scene, 'pn': pn, 'rn': rn}),
      ),
    );
  }

  /// POST /api/v1/gem/purchase/report
  Future<GemPurchaseReport> reportPurchase(
    GemPurchaseReportRequest request,
  ) async {
    return GemPurchaseReport.fromJson(
      await postMap('gem/purchase/report', v1Body(request.toJson())),
    );
  }

  /// POST /api/v1/gem/task/report
  Future<GemTaskActionResult> reportTask(String taskCode) async {
    return GemTaskActionResult.fromJson(
      await postMap(
        'gem/task/report',
        v1Body(<String, Object?>{'task_code': taskCode}),
      ),
    );
  }

  /// POST /api/v1/gem/task/claim
  Future<GemTaskActionResult> claimTask(String taskCode) async {
    return GemTaskActionResult.fromJson(
      await postMap(
        'gem/task/claim',
        v1Body(<String, Object?>{'task_code': taskCode}),
      ),
    );
  }
}
