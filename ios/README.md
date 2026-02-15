# Pomlist iOS 源码（XcodeGen）

## 生成工程

```bash
cd ios
xcodegen generate
```

生成后会得到 `PomlistIOS.xcodeproj`，默认目标为 iOS 17。

## 目录说明

- `project.yml`：XcodeGen 工程描述文件
- `Sources/Models`：SwiftData 模型
- `Sources/Services`：服务层协议与默认实现
- `Sources/Views`：页面层（Unlock/Focus/Tasks/History/Stats）
- `Sources/Components`：共用 UI 组件
