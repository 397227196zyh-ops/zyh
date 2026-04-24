# Phase 1 Demo Acceptance Checklist

- 日期：2026-04-25
- 主题：阶段 1 合并版 EA 在 MT5 demo 账户上的端到端验收
- EA：`Experts/XAUUSD_Scalper/XAUUSD_Scalper_EA.ex5`
- 上游 spec：[2026-04-24-xauusd-mt5-scalper-phase1-merged-design.md](2026-04-24-xauusd-mt5-scalper-phase1-merged-design.md)
- 单元测试口径：`AllTestsEA` 返回 `passed=113 failed=0`（已通过）

## 1. 运行条件

- 账户：MT5 demo
- 品种 / 周期：XAUUSD / M1
- 图表模板：默认即可
- 允许自动交易：是
- 运行时长：连续 8 小时以上（覆盖伦敦 + 纽约主时段）
- EA 输入参数：全部保持默认；`InpDryRun=false`、`InpEnableGuard=true`、`InpEnableTrendConfirm=true`、`InpEnableUnifiedExit=true`
- 首次启动前请确认已执行过 `bash mt5/XAUUSD_Scalper/tools/deploy.sh`

## 2. 产物位置

以下路径均相对于 MT5 的 Data Folder（portable 安装下即 `C:\Program Files\MetaTrader 5\MQL5\`）：

- `Files/XAUUSD_Scalper/Logs/main_YYYYMMDD.log`
- `Files/XAUUSD_Scalper/Logs/trades_YYYYMMDD.log`
- `Files/XAUUSD_Scalper/Logs/execution_YYYYMMDD.log`
- `Files/XAUUSD_Scalper/Logs/market_events_YYYYMMDD.log`
- `Files/XAUUSD_Scalper/Logs/guard_YYYYMMDD.log`
- `Files/XAUUSD_Scalper/Logs/errors_YYYYMMDD.log`
- `Files/XAUUSD_Scalper/decision_snapshots.csv`
- `Files/XAUUSD_Scalper/execution_quality.csv`
- `Files/XAUUSD_Scalper/trade_history.csv`
- `Files/XAUUSD_Scalper/Reports/report-YYYYMMDD.html`
- `Files/xauusd_test_results.txt`（单元测试产物，与 demo 无关）

## 3. 验收口径（12 条，对齐 spec §12.3）

每一条都可以通过产物自动判定。验收脚本：`mt5/XAUUSD_Scalper/tools/audit_demo.sh`。

| # | 条目 | 判定来源 | 判定规则 |
|---|---|---|---|
| 1 | EA 正常编译运行 | `metaeditor.log` + `main_YYYYMMDD.log` | 编译 0 error + 存在 `Init OK` 行 |
| 2 | 三策略独立统计 / 独立开仓 | `trade_history.csv` | 至少在两个 `strat` 值（EMA / BOLL / RSI）下各有过交易 OR 在 `decision_snapshots.csv` 出现 `allowed=1` 的多策略记录 |
| 3 | 仅伦敦 / 纽约盘开仓 | `decision_snapshots.csv` | 所有 `allowed=1` 行的 `session=1` 均为真；亚洲时段 `allowed=1` 行数 = 0 |
| 4 | ExecutionGuard 有效 | `guard_YYYYMMDD.log` | 存在非 0 `guard_reason` 拒单行，涵盖至少一种：`SPREAD`、`ABNORMAL_MARKET`、`COOLDOWN`、`CONSEC_LOSSES`、`DAILY_LOSS`、`SESSION_CLOSED` |
| 5 | M5 趋势确认影响信号放行 | `decision_snapshots.csv` | 存在 `reason=TREND` 的拒绝行；同 EA 运行中也应存在 `allowed=1` 的 `strat=BOLL` 或 `EMA` 放行行 |
| 6 | 统一分层出场生效 | `trade_history.csv` + `main_YYYYMMDD.log` | 至少出现一笔有 "partial TP / 保本 / trailing" 标记的日志，或交易历史中存在单次部分平仓 |
| 7 | 有限加仓，总风险可控 | `trade_history.csv` | 任一 magic 的同向单总次数 ≤ 3 且总理论最大亏损 ≤ 账户净值 5% |
| 8 | 基础风险锚点 0.5% 生效 | `trade_history.csv` + `decision_snapshots.csv` | 每笔 `planned_lot` × `sl_distance × per_lot_ccy` ≤ 账户净值 × 0.5% × 1.01（容差 1%） |
| 9 | 异常行情自动暂停 | `market_events_YYYYMMDD.log` + `guard_YYYYMMDD.log` | 出现过 `MARKET_ABNORMAL` 期间，紧随其后的 `decision_snapshots.csv` 必定为 `allowed=0`，且恢复后出现 `allowed=1` |
| 10 | 数据文件完整 | 上述 4 份 CSV + 6 份 log | 每份文件大小 > 0 且 CSV 头部字段与代码一致 |
| 11 | 回测产物区分维度 | `decision_snapshots.csv` | 存在 `reason=SESSION` / `=GUARD` / `=TREND` / `=NO_SIGNAL` / `=PASS` 全五种区分 |
| 12 | 图表面板 / 交易标注 | 人工截图 | `CDashboard` 面板 + 开平仓箭头可见 |

条目 12 无法自动判定，需要你在 EA 运行期间截图一张面板 + 一笔已成交订单的标注，保存到 `docs/superpowers/specs/2026-04-25-phase1-demo-screenshots/` 下。

## 4. 8 小时体检要点（跑完后读日志即可）

- 信号评估次数：应 ≥ 每分钟 1 次（8h ≈ 500 行以上 decision snapshot）
- `guard_YYYYMMDD.log` 至少 1 条非 0 拒单
- `execution_quality.csv` 至少 1 行成交
- `trade_history.csv` 至少 1 行平仓（若 8h 内没有单，说明 trendConfirm 过严 → 给下一轮验收决定松绑或拉长跑）
- `Reports/report-YYYYMMDD.html` 至少 5 KB，含权益曲线和 guard 柱状图

## 5. 停止与交付

- EA 跑完 8h 后手动卸载（右键图表 → Expert Advisors → Remove），检查 Experts 日志收尾 `deinit` 行已出现。
- 打包 `MQL5/Files/XAUUSD_Scalper/` 整个目录给我（zip 或把路径告诉我即可）。
- 我跑 `bash mt5/XAUUSD_Scalper/tools/audit_demo.sh`，把每一条的 PASS/FAIL 贴出。
- 任意 FAIL 条目我会直接修 EA / 配置，修完你再重跑受影响的片段即可，不用重跑整个 8h。
