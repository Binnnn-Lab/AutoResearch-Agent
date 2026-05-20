Skill Visualizer
=================

目的
---
在不修改原有 `skill` 流程的前提下，为 `paper-discovery` 类 skill 提供本地可运行的可视化前端，展示执行进度、子步骤状态以及结果文件列表。

结构
---
- `server.js` - 后端 Express 服务，定时轮询配置的状态来源（HTTP 或 本地文件），并提供 `/api/status` 与 `/api/results`。
- `public/` - 前端静态页面与资源（`index.html`, `app.js`, `style.css`）。
- `config.example.json` - 示例配置（复制为 `config.json` 并按需修改）。

安装与运行
---
1. 进入目录：

```bash
cd skills/skill-visualizer
```

2. 安装依赖：

```bash
npm install
```

3. 复制配置并修改（可配置为指向 Claude Code 的状态接口，或指向本地状态文件/结果目录）：

```bash
cp config.example.json config.json
# 编辑 config.json：
#  - statusSource.type = "url" 或 "file"
#  - statusSource.url = 指向大模型返回状态的 HTTP 接口（返回 JSON）
#  - statusSource.path = 指向本地 JSON 状态文件
#  - resultsDir = 指向包含结果文件的目录（相对于本目录或绝对路径）
```

4. 启动：

```bash
npm start
```

5. 在浏览器打开 `http://localhost:<port>`（`config.json` 中 `port` 字段，默认 5173）。

如何与 Claude Code 集成
---
- 推荐在你的 Claude Code 执行流程中，定期将执行状态以 JSON 形式发送到一个 HTTP endpoint（例如本地或内部服务），例如：

```
{
  "state": "running",
  "main_step": "03-multi-source-search",
  "sub_steps": [
    {"name":"arXiv search","status":"done"},
    {"name":"OpenAlex search","status":"running"}
  ]
}
```

- 将 `config.json` 中的 `statusSource.url` 指向该 endpoint。

- 如果无法直接推送 HTTP，可把状态写为本地 JSON 文件并把 `statusSource.type` 设为 `file`，`statusSource.path` 指向该文件路径（注意用户偏好：不要在原 skill 目录生成临时文件，建议将状态文件写到独立的结果/状态目录）。

注意事项
---
- 本服务不会修改任何现有 `skill` 脚本。
- 本工具仅做可视化与轮询；实际执行仍由你现有的大模型或脚本触发。

下一步
---
如果你确认无需额外功能，我会继续：
- 在该目录中添加一份 `config.json`（可选，或由你自行复制并配置），并启动本地测试。如需我直接启动/运行测试，请允许我在环境中运行 `npm install` 与 `npm start`（注意：需要网络与 Node 环境）。
