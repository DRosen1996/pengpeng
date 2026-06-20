# 碰碰 PengPeng

基于 Apple Watch 运动数据的附近同项目运动连接 App 原型（本地 Mock 版）。

## 运行

1. 用 Xcode 打开 `PengPeng.xcodeproj`
2. 选择 iPhone 模拟器（iOS 17+）
3. `Cmd + R` 运行

> 首次运行请在 Signing & Capabilities 中选择你的 Development Team。

## 架构

- **SwiftUI** + **MVVM**（`@Observable`，iOS 17+）
- **MapKit**：附近页使用真实地图 + 自定义热区标注（mock 坐标，深圳湾一带）
- 本地假数据：`Mock/MockData.swift`
- 状态流：`NearbyViewModel.activeSheet` 驱动 Sheet 链路

## 交互路径（附近 Tab）

```
地图热区 → 项目 Sheet → 用户列表 → 碰上了 → 运动话题
底部黑卡「碰碰」 → 用户列表（跳过项目 Sheet）
```

## 目录结构

见项目内 `PengPeng/` 源码树。
