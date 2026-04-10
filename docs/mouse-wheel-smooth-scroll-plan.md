# 鼠标滚轮平滑滚动代码级方案

本文档定义 MusicSync 中“桌面端 / Web 鼠标滚轮平滑滚动”的最小实现方案。目标是：在不大范围改造现有页面结构的前提下，为主要滚动区域提供一致、可控、可渐进接入的平滑滚动体验。

## 1. 设计结论

- Flutter 原生支持鼠标滚轮滚动，但默认体验更偏“离散步进”，不等于浏览器或原生桌面应用那种丝滑缓动。
- `ScrollBehavior` 适合作为全局基础配置层，但不能单独解决“滚轮平滑插值”。
- 真正的平滑体验需要在滚轮事件层做处理：监听 `PointerScrollEvent`，把离散 delta 合并成带缓动的 `animateTo`。
- 第一阶段不引入第三方滚动包，优先做项目内统一封装，降低对现有页面和控制器的干扰。
- 第一阶段仅面向桌面端与 Web 的鼠标滚轮输入，不改变移动端滚动语义，不顺带扩展为“鼠标拖拽滚动内容”。

## 2. 实现范围

第一阶段仅新增通用能力，不改业务语义。

涉及文件：

- `lib/app/app.dart`
- `lib/app/scroll/app_scroll_behavior.dart`（新建）
- `lib/app/widgets/smooth_scroll_wrapper.dart`（新建）

首批建议接入页面顺序：

1. `lib/features/settings/presentation/pages/settings_page.dart`
2. `lib/features/preview/presentation/widgets/plan_item_list.dart`
3. `lib/features/home/presentation/pages/home_page.dart`

暂缓接入或需单独验证的区域：

- `ReorderableListView`
- 弹窗内的短列表
- 存在嵌套滚动的复杂区域
- 当前看不到明确收益的短内容区

## 3. 分层方案

### 3.1 全局层：`AppScrollBehavior`

目的：

- 统一桌面 / Web 的基础滚动行为配置
- 作为后续滚动体验扩展的集中入口
- 保持默认平台滚动物理不被局部方案误改

建议职责：

- 继承 `MaterialScrollBehavior`
- 先保持现有平台默认 `dragDevices`
- 保持现有平台默认 physics，不在这里强行做“平滑化”
- 如有需要，可统一 `Scrollbar` 可见性策略

建议接入位置：

- 在 `lib/app/app.dart` 的 `MaterialApp.router` 上增加 `scrollBehavior: const AppScrollBehavior()`

示意代码：

```dart
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();
}
```

说明：

- 这层解决的是“基础行为统一”，不是“滚轮缓动动画”。
- 不建议在这里重写 `getScrollPhysics` 来硬调平滑度，容易把不同平台的触摸/拖拽行为一起带偏。
- 不把 `PointerDeviceKind.mouse` 加入 `dragDevices` 作为第一阶段默认行为。该改动解决的是“鼠标拖拽滚动”，不是“鼠标滚轮平滑”，且可能改变桌面端现有交互语义；如后续确有需求，应单独评估并验证。

### 3.2 组件层：`SmoothScrollWrapper`

目的：

- 为指定滚动区域提供鼠标滚轮平滑滚动能力
- 保持对现有 `ListView` / `SingleChildScrollView` / `CustomScrollView` 的低侵入接入
- 把“滚轮输入处理”限定在单一目标滚动层，避免全局副作用

建议 API：

```dart
class SmoothScrollWrapper extends StatefulWidget {
  const SmoothScrollWrapper({
    required this.controller,
    required this.child,
    this.duration = const Duration(milliseconds: 140),
    this.curve = Curves.easeOutCubic,
    this.scrollDeltaMultiplier = 1.0,
    super.key,
  });

  final ScrollController controller;
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double scrollDeltaMultiplier;
}
```

建议内部逻辑：

- 外层使用 `Listener`
- 在 `onPointerSignal` 中识别 `PointerScrollEvent`
- 仅在桌面端 / Web 启用该逻辑
- 读取 `event.scrollDelta.dy`
- 使用内部 `_targetOffset` 累加目标位置，而不是每次都基于 `controller.offset` 重新计算
- 通过 `clamp` 将目标值限制在 `position.minScrollExtent` 和 `position.maxScrollExtent`
- 使用 `animateTo` 做短时缓动
- 当目标值与当前 `_targetOffset` 相同，或滚动区没有实际可滚动范围时，直接返回

核心示意代码：

```dart
void _handlePointerSignal(PointerSignalEvent event) {
  if (event is! PointerScrollEvent || !_controller.hasClients) {
    return;
  }

  final ScrollPosition position = _controller.position;
  if (position.maxScrollExtent <= position.minScrollExtent) {
    return;
  }

  final double nextTarget =
      (_targetOffset + event.scrollDelta.dy * widget.scrollDeltaMultiplier)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();

  if (nextTarget == _targetOffset) {
    return;
  }

  _targetOffset = nextTarget;
  _controller.animateTo(
    _targetOffset,
    duration: widget.duration,
    curve: widget.curve,
  );
}
```

## 4. 实现细节要求

### 4.1 目标 offset 不能直接取当前 `offset`

错误做法：

- 每次滚轮事件都从 `controller.offset + delta` 计算

问题：

- 连续滚动时，动画尚未完成，新的事件又从“旧位置”起算
- 会出现拖拽感、抖动感或“追不上手”的感觉

正确做法：

- 维护 `_targetOffset`
- 新滚轮事件在 `_targetOffset` 基础上继续累加
- 在 controller 首次 attach、滚动结束或外部跳转后，将 `_targetOffset` 与实际 offset 重新对齐

### 4.2 动画参数要保守

第一阶段建议默认值：

- `duration`: `120ms` 到 `160ms`
- `curve`: `Curves.easeOutCubic`
- `scrollDeltaMultiplier`: `0.9` 到 `1.2`

原因：

- 时长过长会显得“黏”
- 倍率过大容易一下滚太远
- 第一阶段先追求稳定，再做手感调优

### 4.3 只处理垂直滚动

第一阶段仅处理：

- `event.scrollDelta.dy`

不处理：

- 横向滚轮
- shift + 滚轮 的横向语义映射
- 触控板高精度惯性细分

这样可以控制复杂度，避免一次引入过多平台差异。

### 4.4 不劫持没有 controller 的滚动区域

为了保持封装清晰，`SmoothScrollWrapper` 第一版要求：

- 外部必须显式传入 `ScrollController`

不建议第一版做的事：

- 在 wrapper 内部隐式查找最近的 `Scrollable`
- 自动创建控制器并改写子树滚动组件

原因：

- 容易制造隐式状态
- 与仓库“避免隐藏提示、隐式状态和分散语义”的约定冲突

### 4.5 不与用户主动拖拽手势抢控制权

第一阶段应遵循：

- 鼠标滚轮事件可以覆盖上一段尚未结束的平滑动画
- 但不要试图接管用户主动拖拽 `Scrollbar` 或内容区域时的滚动过程
- 若发现当前实现会与拖拽手势互相抢占，应以“保留原生拖拽语义”为优先

原因：

- 该方案要优化的是滚轮输入体验，不是重写整套滚动状态机
- 与原生手势抢控制权，通常比“不够丝滑”更容易制造明显缺陷

### 4.6 嵌套滚动靠接入边界控制，而不是靠运行时猜测

第一阶段明确要求：

- `SmoothScrollWrapper` 只包裹实际希望响应滚轮的那一层滚动容器
- 一个交互路径上不要同时包裹外层与内层滚动区

原因：

- 当前目标是低侵入落地，不做复杂事件仲裁
- 通过接入边界控制风险，比在运行时推断“该由哪一层消费滚轮”更符合项目当前复杂度预算

## 5. 页面接入方式

### 5.1 `ListView`

接入形式：

```dart
final ScrollController controller = ScrollController();

return SmoothScrollWrapper(
  controller: controller,
  child: ListView(
    controller: controller,
    children: ...,
  ),
);
```

说明：

- 本仓库当前未引入 `flutter_hooks`，不要在方案里默认使用 `useScrollController()`
- `controller` 的生命周期应由页面或组件自身显式管理

### 5.2 `SingleChildScrollView`

接入形式：

```dart
return SmoothScrollWrapper(
  controller: controller,
  child: SingleChildScrollView(
    controller: controller,
    child: child,
  ),
);
```

### 5.3 `Scrollbar`

若页面已有 `Scrollbar`，建议层级如下：

```dart
Scrollbar(
  controller: controller,
  child: SmoothScrollWrapper(
    controller: controller,
    child: ListView(
      controller: controller,
      children: ...,
    ),
  ),
);
```

说明：

- `Scrollbar` 和实际滚动组件必须共享同一个 controller
- `SmoothScrollWrapper` 只负责输入和动画，不负责可视滚动条

## 6. 特殊区域处理

### 6.1 `ReorderableListView`

此类列表本身包含拖拽交互。第一阶段建议：

- 先不接入
- 如必须接入，需验证滚轮动画与拖拽句柄不会相互抢占体验

### 6.2 嵌套滚动

若页面存在多层滚动容器，必须明确：

- `SmoothScrollWrapper` 只包裹实际希望响应滚轮的那一层
- 优先接入边界清晰、职责单一的局部列表或整页列表

不要做：

- 外层和内层同时包裹
- 在未验证命中关系前，把方案直接铺到复杂工作台页面

否则容易出现：

- 双重响应
- 焦点不明确
- 滚动距离异常

### 6.3 短内容区域

如果滚动区域内容高度常常不足一屏，可以不接入。原因是：

- 平滑逻辑本身没有收益
- 反而会增加调试面

## 7. 不采用的方案

当前阶段不采用以下路径作为主方案：

- 仅通过 `ScrollPhysics` 调整来追求鼠标滚轮平滑
- 直接全局引入第三方平滑滚动包
- 为 Web 单独切换 renderer 作为主要优化手段
- 通过全局改写 `dragDevices` 顺带引入鼠标拖拽滚动，来替代真正的滚轮平滑处理

理由：

- `ScrollPhysics` 更适合控制边界和平台风格，不是滚轮平滑的主入口
- 第三方包会扩大集成面，且未验证是否与现有页面结构完全兼容
- renderer 选择是平台构建策略，不适合作为应用内滚动体验的一线解法
- `dragDevices` 影响的是拖拽语义，不是滚轮插值语义，混用会模糊本方案目标

## 8. 实施顺序

建议按以下顺序落地：

1. 新建 `lib/app/scroll/app_scroll_behavior.dart`
2. 新建 `lib/app/widgets/smooth_scroll_wrapper.dart`
3. 在 `lib/app/app.dart` 接入全局 `scrollBehavior`
4. 先接入 `settings_page.dart` 做手感验证
5. 再接入 `plan_item_list.dart` 验证与 `Scrollbar` 的配合
6. 最后再评估 `home_page.dart` 是否接入
7. 对特殊滚动组件单独评估是否需要接入

这样排序的原因是：

- `SettingsPage` 是简单整页 `ListView`，最适合先验证基础手感
- `PlanItemList` 已有独立 `ScrollController` 与 `Scrollbar`，适合第二步验证局部列表场景
- `HomePage` 是工作台式长页面，后续更容易遇到外层与局部滚动区并存的情况，应放在前两者稳定之后再决定是否接入

## 9. 验证建议

最小验证：

- `flutter analyze`

建议人工验证场景：

- Windows 鼠标滚轮单次滚动
- Windows 鼠标滚轮快速连续滚动
- 滚动到顶部和底部时是否有抖动
- `Scrollbar` 是否与内容同步
- 页面切换返回后 controller 状态是否正常
- 用户拖拽 `Scrollbar` 时是否仍保持原生语义
- 非目标平台是否没有引入额外交互变化

如项目需要覆盖 Web，再补充验证：

- Chrome 下普通鼠标滚轮
- Chrome 下高分屏设备
- 长列表场景是否掉帧
- Web 下是否出现事件重复响应

回退条件：

- 某页面出现边界抖动、双重滚动、明显掉帧或拖拽交互异常，则该页面先回退不接入，而不是继续扩大接入范围

## 10. 后续可扩展项

如果第一阶段效果基本正确，再考虑以下增强：

- 区分鼠标滚轮与触控板输入
- 针对不同平台设置不同默认倍率
- 支持横向滚动区域
- 支持按页面级配置开关平滑滚动
- 视情况评估是否引入成熟第三方包替换自研实现
- 如确有明确需求，再单独评估是否允许鼠标拖拽滚动内容

## 11. 本方案的边界

本方案解决的是：

- 鼠标滚轮输入的平滑动画体验
- 应用内主要滚动区域的一致性
- 在当前项目复杂度预算内可控落地的局部增强

本方案不承诺一次解决：

- 所有平台上的完全原生手感一致
- 复杂嵌套滚动的全部边界问题
- `ReorderableListView` 等特殊交互组件的全量兼容
- 鼠标拖拽滚动、触控板惯性滚动等其他输入语义

因此实施策略应保持“小步接入、逐页验证、必要时再扩展”。
