# PomlistMigrationV1 导出说明

## 目标

将旧版 `data/pomlist-db.json` 导出为 iOS 可导入的 `PomlistMigrationV1` 文件。

## 命令

```bash
node tools/migration/export-pomlist-migration-v1.mjs \
  --input data/pomlist-db.json \
  --output tools/migration/output/PomlistMigrationV1.json
```

可选参数：

- `-i, --input <path>`：输入 JSON 路径
- `-o, --output <path>`：输出 JSON 路径
- `-h, --help`：帮助

## 输出结构（核心）

- `schema`: 固定 `PomlistMigrationV1`
- `exportedAt`: 导出时间
- `user`: 单用户资料与可选口令
- `todos`: 任务列表
- `sessions`: 会话列表（包含 `tasks` 快照）
- `orphanSessionTasks`: 无法匹配到会话的快照
- `summary`: 导出统计
- `warnings`: 数据修复告警

## 迁移建议

1. 在线上先备份 `data/pomlist-db.json`。
2. 导出后检查 `summary.warningCount`。
3. 将导出的 JSON 传到手机（隔空投送/文件 App）。
4. 在 iOS App 的「统计 -> 设置」中执行导入。
