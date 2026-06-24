# Gateway App Auth

本文件记录 GenesisApp 当前 Gateway 注册、签名和诊断逻辑。实现入口在 `lib/network/gateway_auth.dart`，服务装配在 `lib/app/bootstrap/service_registry.dart`。

## 路由范围

- Gateway 自身接口使用 `https://{host}/apix/` base。
- 业务 HTTP 请求继续走 `https://{host}/api/`，但 `/api/...` 请求必须带 Gateway `X-*` 验签 header。
- Chatroom HTTP `/aitown-chat/...` 请求必须带 Gateway `X-*` 验签 header。
- Chatroom WSS 建联请求也必须带 Gateway `X-*` 验签 header，canonical method 固定为 `GET`，body 为空。
- `/apix/v1/time`、`/apix/v1/app/device/challenge`、`/apix/v1/app/device/register`、`/apix/v1/heartbeat` 不走业务签名重试链路。

## 公共 Header 和签名 Header

公共 header 不再发送旧字段：

- `app-platform`
- `device-id`
- `app-id`
- `app-version`

公共 header 当前只发送：

| Header | 来源 |
| --- | --- |
| `user-agent` | 原生系统名 + 系统版本。Android 为 `Android <Build.VERSION.RELEASE>`；iOS 为 `<UIDevice.systemName> <UIDevice.systemVersion>`。 |

Gateway 签名 header 由 `GatewayRequestSigner` 在发送前统一注入：

| Header | 来源 |
| --- | --- |
| `X-App-ID` | `AppRequestHeaderProvider.gatewayIdentity()` 读取 package name / bundle id 后，用 `HMAC-SHA256(packageName, GENESIS_APP_ID_HMAC_KEY)` 得到小写 hex。 |
| `X-Platform` | `AppRequestHeaderProvider.resolveCurrentPlatform()`，值为 `android` 或 `ios`。 |
| `X-Device-ID` | `DeviceIdService.getDeviceId()`。Android 当前优先 `ANDROID_ID`，无效 fallback 到 AAID，再 fallback 本地 UUID；iOS 为 Keychain 持久化 `ios:<UUID>`。 |
| `X-App-Version` | `AppMetadataService.appVersion().versionName`。该值来自原生包元信息：Android `PackageInfo.versionName`，iOS `CFBundleShortVersionString`。修改 `pubspec.yaml` 版本后必须重新 build/install，hot reload 不会更新该值。 |
| `X-Key-ID` | `/apix/v1/app/device/register` 返回后持久化在 `SharedPreferencesGatewayRegistrationStore`。 |
| `X-Timestamp` | `DateTime.now().millisecondsSinceEpoch + serverTimeOffsetMs`。`serverTimeOffsetMs` 来自 `/apix/v1/time`，只存在当前进程内存；App kill 后重新同步。 |
| `X-Nonce` | 每次签名新生成 16 字节随机数，base64url 无 padding。 |
| `X-Body-SHA256` | 最终实际发送 `bodyBytes` 的 SHA256 小写 hex；空 body 按空字节计算。 |
| `X-Signature-Alg` | 固定 `ECDSA-P256-SHA256`。 |
| `X-Signature` | 原生 Keychain / Keystore P-256 私钥对 canonical string 做 ECDSA ASN.1 DER 签名后 base64url。 |

发送前会移除所有 `X-Verified-*`，这些 header 只允许 Gateway 注入。

## 启动、注册和时间同步

`ServiceRegistry` 在非 mock 环境创建单个 `GatewayAuthCoordinator`，HTTP 和 WSS 共用同一个 coordinator。

启动流程：

1. `GatewayAuthCoordinator.prepare()` 被异步触发。
2. 如果本地没有 `key_id`，通过原生 Keychain / Keystore 生成或读取 P-256 keypair。
3. 调 `/apix/v1/app/device/challenge` 获取 `register_id`。
4. 调 `/apix/v1/app/device/register` 上报 DER SPKI 公钥、`public_key_hash` 和 `attestation`。
5. 服务端返回 `key_id` 后本地持久化。
6. 调 `/apix/v1/time`，计算当前进程内的 `serverTimeOffsetMs`。

请求签名前：

1. `signingContext()` 确保已完成注册。
2. 如果当前进程还没有 `serverTimeOffsetMs`，重新同步 `/apix/v1/time`。
3. 用最终 `Uri`、headers 和 `bodyBytes` 签名。

如果本地私钥签名或公钥读取失败，会清除注册信息、重置原生 key，并重走 challenge/register。

## Canonical String

`gatewayCanonicalString()` 固定按以下行拼接，使用 `\n`：

```text
METHOD
PATH
CANONICAL_QUERY
BODY_SHA256_HEX

X_APP_ID
X_PLATFORM
X_DEVICE_ID
X_APP_VERSION
X_KEY_ID
X_TIMESTAMP
X_NONCE
```

注意 `BODY_SHA256_HEX` 后保留一个空行；当前 `signed_headers` 为空。

Query 规则：

- 使用最终 `Uri.queryParametersAll`。
- 同一个 key 的多个 value 先排序。
- 所有 key/value pair 按 key、value 字典序排序。
- key 和 value 用 `Uri.encodeQueryComponent` 编码后拼成 `key=value`，再用 `&` 连接。

## Retry Policy

`GatewayRequestInterceptor` 只对需要签名的业务请求自动重试一次：

| err_no | 行为 |
| --- | --- |
| `20502` | 同步 `/apix/v1/time` 后重签重试一次。 |
| `20503` | 换新 nonce 后重签重试一次。 |
| `20504` - `20509` | 清除 `key_id`，重置本地 key，重新 challenge/register 后重签重试一次。 |

超过一次仍失败则返回原响应给上层处理。

## 诊断接口

签名诊断接口：

```text
POST /apix/v1/app/device/signature/verify
```

实现入口：

- `GatewayAuthCoordinator.verifyLocalSignature()`
- Developer page 按钮：`Test Gateway signature`

调用方式：

- 使用当前本地 `GatewayAuthCoordinator`，复用同一套 `device_id`、私钥、`key_id` 和 `serverTimeOffsetMs`。
- 请求 body 当前为 `{}`。
- 使用真实 Gateway canonical 规则和 `X-*` headers 签名。
- 直接返回 HTTP status、headers、原始 response body，并在 Developer page 展示，同时 `debugPrint`。

该接口用于排查端上签名差异；服务端即使验签失败也应返回 `err_no=0`，通过 `data.valid`、`reason_code`、`canonical_string`、`checks` 等字段定位问题。

## 开发注意事项

- 改 `X-App-Version` 相关问题时，先确认设备上实际安装包版本。只修改 `pubspec.yaml` 或 hot reload 不会改变原生 `versionName` / `CFBundleShortVersionString`。
- Developer page 的 Gateway host 只配置 host，不配置 `/apix/v1`；保存后由 `AppEndpointOverrideStore.normalizeHttpsGatewayApiBaseUrl()` 归一化到 `https://host/apix/`。
- 清空本地验签信息使用 Developer page 的 `Clear Gateway auth`，它会清除本地 `key_id` 并重置原生 P-256 key。
- 修改 Gateway 逻辑后至少跑：

```sh
flutter test test/network/gateway_auth_test.dart
flutter test test/network/genesis_api_test.dart test/network/chatroom/chatroom_client_test.dart
```
