# PomlistMigrationV1 导出指南

本文档说明如何把旧数据文件 `pomlist-db.json` 导出为迁移格式 `PomlistMigrationV1`。

## 适用场景

- 将 Web 端本地 JSON 数据迁移到 iOS 新工程
- 在导入前先产出标准化中间文件，便于审计和回放

## 输入与输出

- 输入：`data/pomlist-db.json`（可通过参数覆盖）
- 输出：`tools/migration/output/PomlistMigrationV1-时间戳.json`（可通过参数覆盖）

## 执行命令

```bash
node tools/migration/export-pomlist-migration-v1.mjs
```

可选参数：

```bash
node tools/migration/export-pomlist-migration-v1.mjs \
  --input data/pomlist-db.json \
  --output tools/migration/output/PomlistMigrationV1.custom.json
```

查看帮助：

```bash
node tools/migration/export-pomlist-migration-v1.mjs --help
```

## 结构说明

导出文件核心字段如下：

- `schema`：固定为 `PomlistMigrationV1`
- `exportedAt`：导出时间（ISO）
- `source`：来源信息（类型、版本、原文件路径）
- `summary`：导出统计（任务数、会话数、告警数等）
- `warnings`：兼容修复或跳过记录
- `todos`：任务列表（已统一字段）
- `sessions`：会话列表（含内嵌 `tasks`）
- `orphanSessionTasks`：无匹配会话的孤儿会话任务

## 规则与兼容处理

- 缺失 `id` 的记录会自动补 UUID，并写入 `warnings`
- 非法任务状态会回退为 `pending`
- `priority` 会压缩到 1~3
- `tags` 会去重并确保包含 `category`
- 缺少 `session_id` 的会话任务会跳过并写入 `warnings`
- `completedTaskCount` 不会超过 `totalTaskCount`

## 验证建议

导出后至少检查以下内容：

1. `schema` 是否为 `PomlistMigrationV1`
2. `summary.warningCount` 与 `warnings.length` 是否一致
3. `summary.todoCount/sessionCount/sessionTaskCount` 是否符合预期
4. 是否存在需要人工处理的 `orphanSessionTasks`
