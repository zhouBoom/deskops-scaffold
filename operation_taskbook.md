# 人工复核与审查操作手册

> **适用场景**：自动化评测（`tests/test.sh`）已执行完毕后，评卷官对边缘案例进行二次人工审查，或在容器外进行冒烟验收时使用。  
> **前置条件**：服务已通过 `environment/bootstrap.sh` 启动，前后端均处于健康状态。

---

## 一、初始数据核验（开始任何操作前必查）

打开浏览器访问 `http://localhost:5173`，或在容器内执行：

```bash
curl -s http://127.0.0.1:3000/api/inventory/list | python3 -m json.tool | grep -c '"sku_code"'
```

**期望输出**：`15`（恰好 15 条 SKU 记录）。

同时用 SQLite CLI 直接核验种子数据完整性：

```bash
sqlite3 workspace/backend/app.db \
  "SELECT sku_code, name, price, stock, status FROM inventory ORDER BY id;" \
  2>/dev/null
```

**期望**：输出 15 行，price 列全部为**整数**（单位：分），例如 `SKU-1001|MacBook Pro 14"|1499900|42|active`。

| 核查项 | 期望值 | 结果 |
|--------|--------|------|
| 总行数 | = 15 | |
| price 字段类型 | INTEGER（非浮点） | |
| version 字段初始值 | = 1 | |
| 三种 status 均存在 | active / low_stock / out_of_stock | |

---

## 二、4 步人工操作流

> 按顺序执行，每步独立判断 PASS / FAIL。

### Step 1 · Tab 键焦点流转

1. 点击**第 1 行**「修改价格」输入框（列头显示"修改价格（元）"）；
2. 输入任意数字（如 `999`），**不要**按 Enter；
3. 按 **Tab 键**；
4. 观察焦点位置。

| 验收标准 | 期望表现 | PASS / FAIL |
|----------|---------|-------------|
| 焦点未跳出表格 | 光标仍在表格内 | |
| 焦点准确落在第 2 行同列输入框 | 第 2 行价格输入框高亮/选中 | |
| 第 2 行输入框内文字被全选 | 全选（蓝色高亮背景） | |

### Step 2 · Esc 键撤销

1. 点击**任意行**「修改价格」输入框，记录当前显示值（原始价格）；
2. 清空后输入一个错误价格（如 `1`）；
3. 按 **Esc 键**；
4. 观察输入框数值。

| 验收标准 | 期望表现 | PASS / FAIL |
|----------|---------|-------------|
| 输入框值恢复为原始价格 | 与步骤 1 记录的值一致 | |
| 输入框失焦 | 不再有输入光标 | |

### Step 3 · Enter 保存与 F5 刷新持久化

1. 点击**第 3 行**「修改价格」输入框，输入 `500`（即 ¥500.00）；
2. 按 **Enter 键**；
3. 观察：①页面是否出现成功提示 Toast；②「现价（元）」列是否更新为 `¥500.00`；
4. 按 **F5**（或 Ctrl+R）刷新整个页面；
5. 观察第 3 行「修改价格」输入框与「现价」列的值。

| 验收标准 | 期望表现 | PASS / FAIL |
|----------|---------|-------------|
| 成功 Toast 出现 | 绿色提示，包含新价格信息 | |
| 现价列实时更新 | 显示 ¥500.00 | |
| F5 刷新后价格不丢失 | 依然显示 ¥500.00 | |
| SQLite 直连验证（见下） | price=50000, version=2 | |

**刷新后 SQLite 直连验证**（在宿主或容器内执行）：

```bash
sqlite3 workspace/backend/app.db \
  "SELECT id, price, version FROM inventory WHERE id = 3;"
```

期望：`3|50000|2`

### Step 4 · 整数分精度验证

对同一 SKU 连续修改 3 次价格（例如 `100.01` → `200.02` → `300.03`），每次 Enter 后均用以下命令检查：

```bash
sqlite3 workspace/backend/app.db \
  "SELECT price, version FROM inventory WHERE id = 3;"
```

**期望**：`price` 始终为整数（`10001`、`20002`、`30003`），不出现浮点小数，`version` 随每次保存递增。

---

## 三、一票否决项（任一触发即整体 FAIL）

以下行为只要出现一项，**无论自动化评测得分多高**，整体评定为 FAIL：

| 否决项 | 判断方法 |
|--------|---------|
| 前端存在外链 CDN 请求 | 打开浏览器 Network 面板，过滤非 `localhost` 的网络请求 |
| F5 刷新后数据丢失 | 执行 Step 3，刷新后检查 |
| price 以浮点存储 | `sqlite3 app.db "PRAGMA table_info(inventory);"` 确认 price 列类型为 `INTEGER` |
| 运行期发起外部网络请求 | 在 `--network none` 容器中运行时任何网络请求均会失败 |
| 表格行数不足 15 行 | 直接计数 DOM 行数或查 API 返回长度 |

---

## 四、快速故障排查

```bash
# 查看后端日志
cat /app/logs/backend.log

# 查看前端日志
cat /app/logs/frontend.log

# 手动触发 API 保存（用于隔离前后端问题）
curl -s -X POST http://127.0.0.1:3000/api/inventory/update-price \
  -H "Content-Type: application/json" \
  -d '{"id": 1, "price": 99900}' | python3 -m json.tool

# 重置数据库到初始种子状态
cp workspace/backend/seed.db workspace/backend/app.db
```
