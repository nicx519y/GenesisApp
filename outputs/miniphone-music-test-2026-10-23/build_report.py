from pathlib import Path
from html import escape
import json, re, hashlib

ROOT = Path(__file__).resolve().parent
E = ROOT / 'evidence'
env = json.loads((E / 'environment.json').read_text())
rows = [
('M01','目录与播放器入口','通过','已有 World → MiniPhone 第二屏 → 音乐；真实标题、作者、来源和封面成功展示。初始未自动播放。',['14-player-initial']),
('M02','播放、暂停、恢复','通过','首次播放建立 MUSIC 音轨；暂停后两次采样均为 0:09 且音轨 paused。桌面恢复后进度由 1:11 推进至 1:29，音轨 started。',['16-playing-advances','17-paused','18-paused-stable','29-home-playing','30-home-progress']),
('M03','下一首','通过','Keep You Out of the Fire 切换到 Trust the One Who Stays，显示 0:04，系统音轨 started。',['32-next-track']),
('M04','上一首：当前曲重播','通过','当前曲已超过 3 秒时点击上一首，仍为 Trust the One Who Stays 并回到 0:00；后续恢复推进至 0:46。',['33-previous-restart','35-after-switch-settled']),
('M05','上一首：切回前曲','通过（加载完成后）','Sunny Side Up 在 0:00、控件可用时点击上一首，切回 Trust the One Who Stays。缓冲阶段的点击限制另见观察项 O01。',['60-fresh-controls','61-previous-stable-retry','62-previous-stable-ready']),
('M06','封面滑动切歌','通过','在 Trust the One Who Stays 封面右滑，切至 Keep You Out of the Fire；后续播放和拖动使用该曲继续完成。',['36-cover-previous','39-latest-seek-progress']),
('M07','完整播放器连续拖动','通过','连续向前、向后拖动，最后目标约为 1:06；之后显示 1:11 且音轨 started，未回到较早目标。',['38-latest-seek-retest','39-latest-seek-progress']),
('M08','桌面卡片与完整播放器同步','通过','桌面播放进度持续推进，打开完整播放器保持同曲；桌面进度条中心点击可从 0:54 跳至 2:37，暂停状态保持。',['30-home-progress','31-full-player-sync','47-compact-center-seek','49-compact-center-control']),
('M09','桌面进度条扩大触摸区域','失败','中心点击有效；同一目标上方约 18 个逻辑像素处点击无响应，仍停留 0:54。当前紧凑 Slider 高 20，已有测试要求至少 48。',['47-compact-center-seek','48-compact-offset-missed','49-compact-center-control']),
('M10','关闭 MiniPhone 后继续播放','通过','播放器右上角关闭，返回 World 地图；音轨仍为 started。',['40-close-phone-playing']),
('M11','World 浮动音乐按钮','通过','在暂停状态点击手机入口上方的播放气泡，系统音轨恢复 started。',['42-foreground-still-paused','43-dock-resumes']),
('M12','后台暂停与前台恢复规则','通过','返回 Android 桌面后音轨 paused；再打开 Worldo 仍 paused，没有自动恢复播放。',['41-background-paused','42-foreground-still-paused']),
('M13','退出、重进 World','通过','播放中退出 World 后音轨 paused；重进同一 World 后入口音乐提示清空，打开 MiniPhone 保留原歌曲和 1:24 的暂停进度。',['44-leave-world-pauses','45-reenter-world-icon-reset','46-progress-retained']),
('M14','结束后自动下一首','通过','从 Keep You Out of the Fire 的 2:37 附近继续播放至结束，自动进入 Trust the One Who Stays，显示 0:12 且音轨 started。',['50-near-end-playing','51-auto-next']),
('M15','应用进程重启后恢复','通过','Trust the One Who Stays 暂停在 1:12；保留数据结束进程并重新打开，再进入同一 World，仍是同曲 1:12，保持暂停且未建立播放音轨。',['63-before-restart','65-cold-restored']),
]

def links(files, html=False):
    if html:
        return ' · '.join(f'<a href="evidence/{escape(f)}.png">{escape(f.split("-")[0])}</a>' for f in files)
    return ' / '.join(f'[{f.split("-")[0]}]({E / (f + ".png")})' for f in files)

summary = '核心播放、暂停、切歌、拖动、页面间状态同步、后台暂停和重启进度恢复可用。15 项真机检查中，14 项通过（其中上一首按加载完成条件判定），1 项失败。发现 1 个可复现的桌面进度条触摸区域问题，另记录 1 个缓冲体验观察项。本次不作“全部通过”结论。'
issue = [
'影响位置：MiniPhone 桌面音乐卡片，紧凑进度条。建议优先级：P2（交互易用性）。',
'复现：暂停歌曲；点击进度条中心 (400,1697)，显示 0:54；点击目标 (800,1650)，进度仍为 0:54；改点同一横坐标的中心 (800,1697)，成功跳到 2:37。坐标为该 Pixel 6 的物理像素。',
'该机密度 420 dpi，纵向偏移 47 个物理像素约为 17.9 个逻辑像素。当前 compact Slider 高度为 20，偏移点落在实际区域外；已有组件测试要求两种布局均至少 48，并测试中心下方 18 个逻辑像素的拖动。',
'代码测试与真机对照结果一致。可见细轨道保持原样即可，建议扩大透明触摸区域，并回归点击、拖动、页面横滑和相邻按钮。此次只记录问题，未修复代码。',
]
observation = [
'暂停后拖到 0:00，紧接着点击上一首，在两首歌上都观察到短期内仍停留当前曲；第一段约一分钟后采样仍停在 0:00、无 started 音轨。随后下一首可恢复；另一段等待后再点击上一首，可以正常切回前曲。',
'当前两个播放器的上一首／下一首按钮均在 music.loading 时禁用，这与缓冲期间点击无响应的现象相符。未直接读取当时内部 loading 值，也没有抓取媒体请求，所以不能据此确定客户端、CDN、网络或解码器是哪一方造成等待。',
'建议用可控网络条件补测“暂停→归零→立即上一首”，同时记录下载／缓冲状态与按钮是否可用；评估现有界面是否足够说明等待状态。日志中的 MediaCodec Handler 警告已保留，但未证明与此现象存在因果关系，也未观察到由此导致的崩溃。',
]
limits = [
'真机依据为实时截图、操作时间线和 Android AudioPlaybackConfiguration（started／paused、MUSIC、44.1 kHz）。没有进行外放录音或人工听感验收，不能证明音质、音量或无杂音。',
'设备为一台 Pixel 6、Android 17、竖屏、现有账号和同一个 World。未覆盖其他 Android 版本、iOS、蓝牙／耳机、来电中断、横屏／大字体、跨账号／环境切换、跨 World 真机恢复。',
'未执行真机断网／弱网注入、未缓存曲目失败恢复，以及 10 首音频缓存的真实落盘与淘汰验证。缓存、失败保留、生命周期和跳转竞态仅有本次受控代码测试覆盖。',
'初次阶段出现未包含在操作序列内的页面切换，21–25 号阶段不参与验收，用户确认可继续后重新执行关键步骤。播放动画期间 UIAutomator 可能不能生成新界面树，早期 XML 不单独作为结果依据；后续主要使用截图与音轨状态，并对需要的静态界面删除旧树后重新读取。',
'本次使用 production release 包及真实现有账号，未启用 mock。未独立审计账号保存的 API host 覆盖设置，因此不将客户端真实运行结果扩大为指定后端环境的完整验收。',
]
commands = '''cd /Users/ionix/Works/GenesisAppTilemap/genesis_app
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter pub get --enforce-lockfile
flutter build apk --release --flavor production --target-platform android-arm64 --no-pub
flutter test --no-pub \\
  test/pages/mini_phone/mini_phone_music_service_test.dart \\
  test/pages/mini_phone/mini_phone_music_cache_test.dart \\
  test/pages/mini_phone/mini_phone_music_owner_test.dart \\
  test/pages/mini_phone/mini_phone_music_lifecycle_test.dart \\
  test/pages/mini_phone/mini_phone_music_page_test.dart \\
  test/pages/mini_phone/mini_phone_music_cover_swipe_test.dart \\
  test/pages/mini_phone/mini_phone_music_widgets_test.dart \\
  test/pages/mini_phone/mini_phone_entry_music_world_test.dart \\
  --reporter expanded
adb -s 1A101FDF6006AX install -r build/app/outputs/flutter-apk/app-production-release.apk
git diff --check'''

md = ['# MiniPhone 音乐播放测试报告', '', '**Android 真机 · 2026-10-23 · Asia/Shanghai**', '', summary, '',
'## 测试环境', '',
f'- 设备：Pixel 6 / Android 17 / 1080 × 2400 / 420 dpi。',
f'- 应用：`com.worldo.ai`，9.9.9 (999)，production release，ARM64。',
f'- 源码：`{env["repository"]}`；提交 `{env["commit"]}`。',
f'- APK SHA-256：`{env["apk_sha256"]}`。已与手机实际安装包核对一致。',
f'- 构建与测试工具：Flutter {env["flutter"]} / Dart {env["dart"]}；最终构建和测试使用仓库锁定依赖。',
f'- 真机执行：{env["device_test_start"]} 至 {env["device_test_end"]}；World：Spoiled by the Seven Archons。',
'- 由用户完成账号登录；覆盖更新保留应用数据。未清账号、未清缓存、未修改业务代码，源码仓库结束时干净。', '',
'## 真机检查结果', '', '| ID | 检查点 | 结果 | 实际观察 | 截图证据 |', '|---|---|---|---|---|']
for i,name,status,detail,files in rows:
    md.append(f'| {i} | {name} | {status} | {detail} | {links(files)} |')
md += ['', '每个截图同名的 `.audio.txt` 保存对应系统音频状态；截图和音轨采样存在短暂时间差。操作时间线见 [actions.jsonl]('+str(E/'actions.jsonl')+')。', '',
'## 已确认问题 F01：桌面进度条触摸区域过窄', '']
md += ['- '+p for p in issue]
md += ['', f'![左：中心点击后 0:54；中：偏移点击无效；右：中心对照点击到 2:37]({E / "compact-comparison.png"})', '',
'代码位置：[mini_phone_music_widgets.dart:406](/Users/ionix/Works/GenesisAppTilemap/genesis_app/lib/pages/mini_phone/music/mini_phone_music_widgets.dart:406)；失败用例：[mini_phone_music_widgets_test.dart:218](/Users/ionix/Works/GenesisAppTilemap/genesis_app/test/pages/mini_phone/mini_phone_music_widgets_test.dart:218)。', '',
'## 观察项 O01：归零与切歌期间的等待', '']
md += ['- '+p for p in observation]
md += ['', '证据：'+links(['52-at-start-paused','53-previous-from-start','54-before-offline','55-recovery-next','57-repro-zero','59-repro-stable','62-previous-stable-ready'])+'。`54-before-offline` 为取证文件名，本次没有实际关闭网络。', '',
'## 受控代码测试', '',
'8 个音乐相关测试文件，共 69 项：**68 通过、1 失败**。失败为 `tap and enlarged drag hit-area each submit exactly one seek (compact=true)`，断言期望 Slider 高度 ≥ 48，实测 20.0。缓存、服务、生命周期、World 所有权、页面和封面手势等其余用例通过。受控测试没有真实音频设备或后端证明力。', '',
f'- [最终测试日志]({E / "flutter-tests-locked.log"})',
f'- [最终构建日志]({E / "build-locked.log"}) · [安装日志]({E / "install.log"}) · [包校验]({E / "installed-apk-sha256.txt"})',
f'- [设备警告日志]({E / "device-warnings.log"}) · [环境记录]({E / "environment.json"})', '',
'首次依赖解析自动改变过镜像地址和部分 SQLite 包版本；这些改动已撤销，最终采用 `--enforce-lockfile` 重新准备，并重新构建、重跑上述 69 项测试。最终源码和锁文件无差异。', '',
'## 覆盖边界与现场状态', '']
md += ['- '+p for p in limits]
md += ['', '**结束状态：** MiniPhone 桌面，Trust the One Who Stays 暂停于 1:12；账号与缓存保留；Wi-Fi 和移动数据仍开启。', '',
f'![左：重启前；右：重启后，同曲 1:12 且暂停]({E / "restart-comparison.png"})', '',
'## 实际执行的主要命令', '', '```sh', commands, '```', '',
'建议先修复 F01，再复测桌面进度条；O01 需要进一步采集缓冲与网络证据。此次没有提交或推送代码。', '']
(ROOT/'测试报告.md').write_text('\n'.join(md))

def paragraphs(items): return ''.join('<p>'+escape(p)+'</p>' for p in items)
html_rows=''.join(f'<tr><td>{i}</td><td>{escape(name)}</td><td class="{"bad" if status=="失败" else "good"}">{escape(status)}</td><td>{escape(detail)}</td><td>{links(files,True)}</td></tr>' for i,name,status,detail,files in rows)
html=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>MiniPhone 音乐播放测试报告</title>
<style>body{{margin:0;background:#f2f4f7;color:#1b2637;font:16px/1.7 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}}main{{max-width:1100px;margin:40px auto;padding:48px;background:white;border-radius:18px}}h1{{font-size:36px;line-height:1.25;letter-spacing:-1px}}h2{{margin-top:36px;font-size:23px}}.eyebrow{{font-size:13px;letter-spacing:2px;color:#64748b}}.lead{{font-size:18px}}.stats{{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin:30px 0}}.stat{{background:#f3f6fa;padding:20px;border-radius:12px}}.stat strong{{font-size:32px;display:block}}.good{{color:#087f5b;font-weight:600}}.bad{{color:#c53c35;font-weight:600}}.note{{padding:20px 24px;border-left:4px solid #d99528;background:#fff9ed}}table{{border-collapse:collapse;width:100%;font-size:14px}}th,td{{padding:12px 10px;text-align:left;border-bottom:1px solid #e2e8f0;vertical-align:top}}th{{background:#f3f6fa}}td:first-child{{white-space:nowrap}}td:nth-child(3){{min-width:86px}}a{{color:#175cd3;text-decoration:none}}a:hover{{text-decoration:underline}}.meta{{font-size:14px;color:#475569;overflow-wrap:anywhere}}.wide{{width:100%;border-radius:10px}}.caption{{font-size:13px;color:#64748b}}pre{{white-space:pre-wrap;overflow-wrap:anywhere;background:#152133;color:#e4edf9;padding:24px;border-radius:12px;font-size:12px}}details{{margin:20px 0}}footer{{margin-top:40px;border-top:1px solid #ddd;padding-top:16px;color:#64748b;font-size:13px}}@media(max-width:700px){{main{{margin:0;padding:24px;border-radius:0}}.stats{{grid-template-columns:repeat(2,1fr)}}.table{{overflow:auto}}h1{{font-size:28px}}}}@media print{{body{{background:white}}main{{margin:0;padding:0}}tr,img{{break-inside:avoid}}.stats{{margin:18px 0}}}}</style>
<main><div class="eyebrow">ANDROID DEVICE TEST · 2026-10-23</div><h1>MiniPhone 音乐播放<br>测试报告</h1><p class="lead">{escape(summary)}</p>
<div class="stats"><div class="stat"><strong>15</strong>真机检查项</div><div class="stat"><strong class="good">14</strong>通过</div><div class="stat"><strong class="bad">1</strong>可复现问题</div><div class="stat"><strong>68/69</strong>代码测试通过</div></div>
<div class="meta"><b>设备</b> Pixel 6 · Android 17 · 1080×2400 · 420 dpi<br><b>应用</b> com.worldo.ai · 9.9.9 (999) · production release ARM64<br><b>执行时间</b> {escape(env['device_test_start'])} — {escape(env['device_test_end'])}<br><b>代码提交</b> {escape(env['commit'])}<br><b>APK SHA-256</b> {escape(env['apk_sha256'])}<br>已核对手机实际安装包；最终使用仓库锁定依赖。账号、缓存保留，业务代码未修改。</div>
<h2>真机检查结果</h2><div class="table"><table><thead><tr><th>ID</th><th>检查点</th><th>结果</th><th>实际观察</th><th>截图</th></tr></thead><tbody>{html_rows}</tbody></table></div>
<h2>F01 · 桌面进度条触摸区域过窄</h2><div class="note">{paragraphs(issue)}</div><p><img class="wide" src="evidence/compact-comparison.png" alt="三次点击的对照截图"></p><p class="caption">左：中心点击后 0:54；中：上移约 18 个逻辑像素点击无响应；右：同一横坐标中心点击到 2:37。</p><p class="meta">源码：mini_phone_music_widgets.dart:406；失败测试：mini_phone_music_widgets_test.dart:218。</p>
<h2>O01 · 归零与切歌期间的等待</h2>{paragraphs(observation)}<p>证据：{links(['52-at-start-paused','53-previous-from-start','54-before-offline','55-recovery-next','57-repro-zero','59-repro-stable','62-previous-stable-ready'],True)}。54 号文件的名称包含 offline，但本次未关闭网络。</p>
<h2>受控代码测试</h2><p>8 个测试文件共 69 项：68 通过、1 失败。失败断言要求紧凑 Slider 高度至少 48，实际为 20.0，与真机触摸对照结果一致。其余服务、缓存、生命周期、World 所有权、页面与封面手势用例通过。此层结果不替代真实设备与服务验证。</p><p><a href="evidence/flutter-tests-locked.log">最终测试日志</a> · <a href="evidence/build-locked.log">构建日志</a> · <a href="evidence/install.log">安装日志</a> · <a href="evidence/installed-apk-sha256.txt">安装包校验</a> · <a href="evidence/device-warnings.log">设备警告</a> · <a href="evidence/actions.jsonl">操作时间线</a></p>
<h2>覆盖边界</h2>{paragraphs(limits)}
<h2>结束状态</h2><p>手机停在 MiniPhone 桌面，Trust the One Who Stays 暂停于 1:12。账号与缓存保留，Wi-Fi 和移动数据仍开启。未修改、提交或推送业务代码。</p><img class="wide" src="evidence/restart-comparison.png" alt="重启前后保持同曲同进度"><p class="caption">左：应用重启前；右：应用重启后，同曲 1:12、保持暂停。</p>
<details><summary>构建与测试命令</summary><pre>{escape(commands)}</pre><p>首次依赖自动解析造成的变更已撤销；最终依赖锁定后重新构建和重跑测试。源码仓库结束时干净。</p></details>
<footer>证据以本次运行记录为准。建议修复 F01 后针对性回归；O01 需要补充可控网络与缓冲诊断。<br>生成于 {escape(env['device_test_end'])} · <a href="测试报告.md">Markdown 报告</a> · <a href="evidence/environment.json">完整环境记录</a></footer></main></html>'''
(ROOT/'测试报告.html').write_text(html)
(E/'results.json').write_text(json.dumps([dict(id=i,name=n,status=s,observation=d,evidence=f) for i,n,s,d,f in rows],ensure_ascii=False,indent=2))
for _,_,_,_,files in rows:
    for f in files:
        assert (E/(f+'.png')).is_file(), f
manifest={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in E.iterdir() if p.is_file() and p.name!='manifest.sha256.json'}
(E/'manifest.sha256.json').write_text(json.dumps(manifest,indent=2))
print('Created Markdown and HTML reports. 15 device checks: 14 passed, 1 failed. Evidence links verified.')
