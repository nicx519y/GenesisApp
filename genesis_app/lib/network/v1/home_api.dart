import 'v1_api_resource.dart';

class HomeV1Api extends V1ApiResource {
  const HomeV1Api(super.client);

  /// GET /api/v1/home
  ///
  /// 提交参数: 无
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"default_tab":"my_world","my_world":{"list":[{"oid":"string","wid":"string","status":1,"name":"string","cover":"string","owner_uid":"string","owner_name":"string","tick_cnt":0,"connect_cnt":0,"ai_character_cnt":0,"player_cnt":0,"last_progress_at":"string","last_progress_summary":"string","updated_at":"string"}]},"popular":{"list":[{"oid":"string","status":1,"version_num":1,"name":"string","cover":"string","display_subtitle":"string","tags":[],"copy_cnt":0,"connect_cnt":0}]},"following":{"list":[]}}}
  /// ```
  Future<Map<String, dynamic>> home() => getMap('home');

  /// GET /api/v1/home/following
  ///
  /// 提交参数:
  /// ```json
  /// {"pn":1,"rn":10}
  /// ```
  ///
  /// Response:
  /// ```json
  /// {"err_no":0,"err_str":"success","data":{"list":[{"event_type":"world_launch","event_time":"string","actor":{"uid":"string","name":"string","avatar":"string"},"target":{"oid":"string","wid":"string","name":"string","cover":"string","tick_cnt":0},"summary":"string"}],"total":0,"has_more":false}}
  /// ```
  Future<Map<String, dynamic>> following({int? pn, int? rn}) {
    return getMap('home/following', v1Query({'pn': pn, 'rn': rn}));
  }
}
