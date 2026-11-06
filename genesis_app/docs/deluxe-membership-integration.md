# Deluxe 独立会员接入

## 范围

在 worldo_1 main 接入 Premium / Deluxe 两种独立、可共存的会员。worldo_2 的 feature/global-memory-deluxe-20261104 只提供卡片、轮播、渐变、套餐控件和皇冠外观；未迁移其 Developer 模拟状态、固定价格或 Deluxe 不可购买适配器，也未迁移 World Memory 功能。

## 数据与购买

- 商品接口一次返回 list、list_deluxe、has_purchased 和两组原购买 UUID。模型保留分组，allProducts 只用于统一平台查询及按唯一 plan_code 查找，不把一组身份应用于另一组。
- 新 plan_code 为 deluxe_monthly / deluxe_yearly。Premium 的 pro_monthly / pro_yearly 保持兼容。月转年、重复订阅、年转月拦截仅检查同组。
- 展示缓存保存两组商品、平台展示价格和默认定位标志，不保存购买 UUID；原生商品准备、缓存补查、支付超时、报告、恢复及游客认领复用现有实现。缓存缺失时仍由原流程加载，不通过 UI 声明购买成功。
- 价格沿用 MembershipOffer.price 的币种白名单与服务端兜底，不使用设计稿价格。权益行读取商品 benefits，年付优惠比例只比较同组、同币种商品。
- 钱包保留两个摘要及独立有效状态；共享会员权益采用任一有效组，购买资格按所属组判断，Gems 商品和购买链路保持原实现。
- 事件名称、action_type、入口 source、失败诊断不另起一套，通过 SKU/base plan 区分商品；Deluxe 购买中和服务端确认后的成功提示使用对应文案与皇冠。

## 页面

- 所有 ProSubscriptionContent 宿主（Home/Me 路由进入、完整支付页、支付 sheet、表单后订阅及现有嵌入入口）复用新的双会员展示及原购买处理器，不增加二次跳转到旧购买页。
- 完整支付页与购买 sheet 的 Subscription 指示器优先采用已选会员、指定入口会员或缓存默认会员的颜色，不等待懒加载正文才从金色修正。Premium / Deluxe 切换时，指示器平滑变色，底部订阅按钮和套餐框随卡片的拖动与松手动画渐变；确认切换时立即更新价格、优惠和订阅按钮文案；Subscription / Buy Gems 的颜色由外层 Tab 实际动画进度插值，Gems 页面期间先同步好会员颜色，避免返回时经过旧金色。
- 完整支付页与购买 sheet 保留外层 Subscription / Buy Gems 横滑。会员卡内先切换 Premium / Deluxe；在 Deluxe 末端向左净拖动超过 12px 时，同一次手势转交外层 TabBarView。进度跟手。从 Buy Gems 右滑返回。外层双向慢拖实际滚动达到 48 个逻辑像素即可切页，短于门槛的慢拖回弹。无外层支付 Tab 的嵌入入口不转发，Me 卡片轮播独立。
- 完整支付页首次横滑露出未进入的 Tab 时展示静态骨架。购买 Sheet 优先显示当前会话的缓存商品，无缓存时展示静态骨架。只有确认进入该 Tab 后才启动商品刷新及购买相关服务。
- Me 会员卡轮播使用完整页面宽度，由轮播自身提供一次 16px 左右边距，外层不得再加 Padding。Me 卡宽为可用宽度减 104 后限制在 180 至 216，最小高度 126，卡片间隔 10。卡片分为名称、到期信息或两行权益、状态标签或订阅按钮三段。Me 横滑松手后吸附到卡片端点，Me 小卡片使用 12px 拖动门槛，并识别速度至少 200px/s 且实际位移至少 8px 的快速轻扫；很小的慢拖回到当前卡，Subscription 沿用 feature/global-memory-deluxe-20261104 的原 GestureDetector、超过 12px 的位移门槛，松手后使用 480ms 切换动画，不采用 Me 的轻扫配置；保留初始定位及用户手动选择，不停留在两卡中间。
- 已订阅且自动续费中的当前套餐显示弱化渐变的 `Subscribed` 状态，按钮不可点击。
- Premium 和 Deluxe 的年付卡片显示折算后的月均价，并标注按年计费。选中年付时，底部按钮显示年付总价。
- 新用户订阅 Sheet 的顶部名称和皇冠随会员卡切换。订阅套餐卡和底部按钮在没有可显示价格时使用 `--`。
- Me 使用双会员卡入口，点击某卡定位该组；卡片显示各自状态和到期时间。粉钻以 membership.blue_gems_cent + membership_deluxe.blue_gems_cent 的整数 cent 和展示，普通余额不变。
- 已登录时，首次进入、切回 Me 或下拉刷新会请求当前用户资料、钱包、Origins 和 Worlds 的第一页，以及受支持平台的会员商品。刷新期间保留已有数据显示，下拉等待这一轮请求结束。
- 卡片始终按 Premium / Deluxe 排列。Me 初始优先定位有效会员，两档都有效定位 Deluxe；两档都无效才按 has_purchased 定位。Subscription 初始按 has_purchased 定位。使用 has_purchased 时，true 定位第二张 Deluxe，false 定位第一张 Premium。用户已切换的卡片和每组月年选择在刷新期间保留。
- 名字后的图标仅读取所属用户的两种 status；1 显示，0/2/非法/缺失不显示，删除用户不显示。双图标顺序为 Deluxe / Premium，与卡片排序无关。不新增徽章网络请求，World/Chat/LocationChat 保留原展示范围。

## 验证

覆盖两平台的 Deluxe 商品与购买身份、双摘要与粉钻相加、组间互不阻塞、原生参数、展示缓存恢复、两种默认定位、双徽章及新 UI 购买选择。实际商店配置与真实交易需在各自测试商店验证；UI 和单元测试不替代商店验收。
