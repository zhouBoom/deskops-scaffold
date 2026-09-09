# Harbor Coding Benchmark – Mother Project

## 工程概览

```
pc/
├── environment/
│   ├── Dockerfile          # 基于 playwright:v1.45.0-jammy，构建期完成所有依赖安装
│   ├── bootstrap.sh        # 毫秒复位DB → 启动后端 → 启动前端 → 就绪探活
│   └── teardown.sh         # 逆序清理进程，释放端口
│
├── workspace/
│   ├── backend/
│   │   ├── package.json    # express, cors, better-sqlite3
│   │   ├── db.js           # SQLite 初始化 + 15条真实种子数据（整数分）
│   │   ├── server.js       # Express 入口，0.0.0.0:3000
│   │   └── routes/
│   │       └── inventory.js # GET /list · POST /update-price（事务+回滚）
│   │
│   └── frontend/
│       ├── package.json    # vue, element-plus, axios, vite
│       ├── vite.config.js  # proxy /api→3000, port 5173, host 0.0.0.0
│       ├── index.html      # 零外链CDN
│       └── src/
│           ├── main.js     # ElementPlus 全量注册
│           ├── App.vue     # 220px侧栏 + 顶栏 + 主工作区
│           └── views/
│               └── InventoryWorkbench.vue  # 核心调价工作台
│
└── tests/
    ├── package.json        # @playwright/test, better-sqlite3
    ├── playwright.config.js # chromium 无头, 1920×1080, workers=1
    └── e2e/specs/
        └── workbench.spec.js # 7个断言覆盖全部验收场景
```

## 快速启动（本地开发）

```bash
# 1. 安装依赖
cd workspace/backend  && npm install
cd workspace/frontend && npm install
cd tests              && npm install

# 2. 初始化数据库
cd workspace/backend && node db.js --seed

# 3. 启动后端
cd workspace/backend && node server.js &

# 4. 启动前端（开发模式）
cd workspace/frontend && npm run dev

# 5. 运行测试（确保前后端已启动）
cd tests && npx playwright test
```

## Docker 构建与运行

```bash
# 构建（断网可运行镜像）
docker build -f environment/Dockerfile -t harbor-benchmark .

# 运行（完全断网）
docker run --network none -p 3000:3000 -p 5173:5173 harbor-benchmark

# 运行测试（在容器内）
docker exec -it <container> bash -c "cd /app/tests && npx playwright test"
```

## 架构要点

| 约束 | 实现方式 |
|------|---------|
| 断网自洽 | 所有 npm 依赖构建期安装；Element Plus 本地打包；零 CDN |
| 整数分防精度 | price 字段 INTEGER，前端 `Math.round(yuan * 100)` 转换 |
| 键盘行内流转 | keydown 捕获 Tab/Enter/Esc，`event.preventDefault()` 阻止默认跳出 |
| 真实落库 | 每次 Enter/点击保存均发 POST，后端 SQLite 事务写入 |
| F5 持久化 | 刷新后 `GET /api/inventory/list` 重新拉取，显示持久化数据 |
| 数据库直连断言 | 测试用 better-sqlite3 直连 app.db 验证 price 分值与 version |
