# 台灣繁體中文翻譯檢核

基準：`lib/l10n/app_en.arb`，共 779 個文案 key。譯文：`lib/l10n/app_zh_TW.arb`；飛書「多語言翻譯」工作表 E3:E781 與譯文逐 key 比對一致，A:D 未改動。`app_zh.arb` 僅供 Flutter 產碼所需的語言後備；非台灣中文暫時顯示英文。

## 已採用術語

- `Worldo`、`#Worldo`、小寫 `worldo` 保留品牌拼法；作品類型 `World/Worlds` 譯為「世界」。
- `Gem/Gems` 譯為「寶石」，`Pink Gems` 為「粉寶石」，`Red Gems` 為「紅寶石」。
- `Premium` 保留英文；`Discuss` 依位置使用「討論／討論區」；`Inspiration` 譯為「靈感」。
- `Tick` 作名詞暫譯「回合」，推進動作依情境譯為「推進／立即推進」；從 Worldo 生成世界的 `Launch` 譯為「開啟世界」，其他情境按實際操作翻譯。
- 平台名稱、UID/OID/WID、AI/NPC、貨幣與格式縮寫、`{...}` 參數及 ICU 語法均保留；`LLM`、`EULA` 暫保留原文。

## 待產品確認

- `Tick` 是否確實表示完整的世界推進回合，以及子 Tick 編號是否符合「第 {tick}{suffix} 回合」的閱讀方式。
- `worldDetailLaunchFailed` 的英文是「Launch failed」，但位置說明涉及加入／進度流程；目前暫譯「開啟失敗」，須以實際觸發情境確認。
- `LLM` 與 `EULA` 是否需要改為面向一般使用者的中文名稱。
- 範例中的 `Main Street`、`Labor Day`、`Joe's Diner` 暫作故事專有名詞保留，須確認是否希望改為台灣在地化範例。
- 帳號刪除、寶石失效、訂閱與退款相關文字需產品／法務核對語義後上線。

## 上線前 UI 檢查

- 在台灣地區語言、`zh-Hant-TW` 系統語言，以及 App 內切換語言後檢查首頁、Create、Inbox、Me、寶石錢包和訂閱頁。
- 檢查富文本的品牌上色、可點擊連結、圖示占位符，以及 21 條含換行文案的實際排版。
- 檢查 ICU 複數、動態數字／人名／世界名、不同螢幕尺寸、長文案截斷和原生 iOS 權限彈窗語言。
- 本次已通過 `flutter gen-l10n` 和本地化單元測試；尚未作真機逐頁視覺驗收。
