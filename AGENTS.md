# zig-jinja 编程入口

> 本文档用于指导 AI 助手（如 GitHub Copilot、Cursor、Claude）理解并辅助开发 zig-jinja（Zig 0.16.0）。
> 请严格遵循以下目标、约束及设计决策。

## 🎯 项目目标

实现一个**生产级、高性能、跨平台**的 Jinja2 兼容模板引擎，完全基于 **Zig 0.16.0**。

## ⚠️ 核心约束

1. **Zig 0.16.0 特定行为**
   - 必须适配 I/O 接口化（`std.Io`），阻塞操作需通过 `io` 实例。
   - `build.zig` 中不得使用已废弃的 `exe.linkSystemLibrary`；改用 `exe.root_module.linkSystemLibrary`。

2. **Zig 0.16.0 I/O 接口化约束**
   - **所有**阻塞 I/O 操作必须通过 Io 实例完成，函数签名应显式传递 Io 参数（类似 Allocator 模式）。
   - 使用 **Juicy Main** 获取预初始化的 Io 实例：`pub fn main(init: std.process.Init) !void { const io = init.io; ... }`。
   - 不再使用 `std.fs.cwd()` 等旧 API，改用 `std.Io.Dir.cwd().openFile(io, ...)` 模式。
   - 如需自定义 Io 实现，使用 `std.Io.Threaded`（稳定、功能完整），`std.Io.Evented` 仍处于实验阶段。

3. **时间测量约束（Zig 0.16.0 破坏性变更）**
   - `std.time.Timer` 已被移除，`std.time.nanoTimestamp()` 不再是推荐方式。
   - 新 API：使用 `std.Io.Clock.now(.awake, io)` 获取时间戳。

4. **移除 `std.heap.GeneralPurposeAllocator`**
   - 将测试文件中所有 `GeneralPurposeAllocator` 替换为 `std.testing.allocator`。
   - `main` 函数中可以使用 `init.allocator` 或 `std.heap.c_allocator`。

5. **根文件导入规则**
   - 不得在根文件中使用相对路径导入另一个根文件（例如 `@import("../foo.zig")`）。
   - 所有导入必须使用绝对路径（基于模块根）或通过 `build.zig` 显式添加模块。

6. **错误处理与资源管理**
   - 善用 `defer` 和 `errdefer` 管理资源。
   - 避免未定义行为（如数组越界、空指针解引用）。

## 🧩 Zig 0.16.0 迁移常见问题及修复

> 以下变更可能破坏现有代码，请按需修改。

### 1. I/O 接口化：所有阻塞操作必须通过 `std.Io`

**破坏性**：`std.fs.cwd()`, `std.fs.openFileAbsolute`, `std.net`, `std.time.sleep` 等直接阻塞 API 被移除。

**修复**：函数签名需接受 `io: *std.Io` 参数，所有文件/网络操作通过 `io` 实例完成。

```zig
// ❌ 旧代码
const file = try std.fs.cwd().openFile("data.txt", .{});
const stat = try file.stat();
var buf = try std.ArrayList(u8).initCapacity(allocator, stat.size);
_ = try file.readAll(buf.items);

// ✅ 新代码 (0.16.0)
pub fn main(init: std.process.Init) !void {
    var io = init.io;
    var cwd = try std.Io.Dir.cwd(&io);
    const file = try cwd.openFile(&io, "data.txt", .{});
    defer file.close();
    const stat = try file.stat(&io);
    var buf = try std.ArrayList(u8).initCapacity(allocator, stat.size);
    _ = try file.readAll(&io, buf.items);
}
```

### 2. `std.heap.GeneralPurposeAllocator` 被移除

**破坏性**：该分配器已在 0.14.0 弃用，0.16.0 完全删除。

**修复**：
- 测试代码统一使用 `std.testing.allocator`。
- 生产代码使用 `std.heap.c_allocator` 或 `std.heap.page_allocator`，或自定义分配器。

```zig
// ❌ 旧代码
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();

// ✅ 新代码
const allocator = std.testing.allocator;  // 测试中
const allocator = std.heap.c_allocator;   // 生产（需要链接 libc）
```

### 3. `std.time.Timer` 被移除，时间获取方式改变

**破坏性**：`Timer` 类及 `nanoTimestamp()` 不再可用。

**修复**：使用 `std.Io.Clock.now(.awake, io)` 获取单调时间戳。

```zig
// ❌ 旧代码
var timer = try std.time.Timer.start();
// ...
const elapsed = timer.read();

// ✅ 新代码
const start = try io.clock.now(.awake);
// ...
const end = try io.clock.now(.awake);
const elapsed = end - start;  // 纳秒
```

### 4. `std.ArrayList(T).toOwnedSlice()` 现在返回 `![]T`

**破坏性**：该方法不再返回切片，而是可能失败（例如内存不足）。

**修复**：调用处加上 `try` 或 `catch`。

```zig
// ❌ 旧代码
const slice = try list.toOwnedSlice();

// ✅ 新代码
const slice = try list.toOwnedSlice();  // 现在需要 try
```

### 5. `std.Build` 中 `exe.linkSystemLibrary` 等已废弃

**破坏性**：`linkSystemLibrary` 被移除，改用 `exe.root_module.linkSystemLibrary`。

**修复**：更新 `build.zig` 中的链接方式。

```zig
// ❌ 旧代码
exe.linkSystemLibrary("c");

// ✅ 新代码
exe.root_module.linkSystemLibrary("c");
```

### 6. `std.json` 解析器现在要求显式指定分配器

**破坏性**：`std.json.parse` 等函数不再隐式使用全局分配器，必须显式传递 `Allocator`。

**修复**：确保每个 `parse` 调用都传入 `allocator`。

```zig
// ❌ 旧代码
const parsed = try std.json.parse(MyStruct, json_string, .{});

// ✅ 新代码
const parsed = try std.json.parse(MyStruct, json_string, .{}, allocator);
defer parsed.deinit();
```

### 7. 根文件导入规则变更

**破坏性**：不再允许在根文件中使用相对路径导入另一个根文件（即 `@import("../foo.zig")` 可能失败）。

**修复**：所有导入必须使用绝对路径（基于模块根）或通过 `build.zig` 显式添加模块。

```zig
// ❌ 旧代码
const utils = @import("../utils.zig");

// ✅ 新代码（假设 utils 在根路径下）
const utils = @import("utils.zig");
// 或者在 build.zig 中添加模块：
// exe.addModule("utils", .{ .source_file = .{ .path = "src/utils.zig" } });
```

### 8. `std.meta.Tag` 等反射 API 行为微调

**破坏性**：某些反射函数的返回值类型可能变为非推断型，需要显式类型标注。

**修复**：在复杂泛型代码中，可能需要添加 `@TypeOf` 或显式类型转换。

### 9. `std.Build` 的 `addExecutable` 等函数不再接受可执行文件名参数

**破坏性**：可执行文件名现在通过 `root_module` 的 `main_mod` 设置。

**修复**：使用 `addExecutable(.{ .name = "myexe", .root_source_file = ... })` 的命名参数模式。

```zig
// ❌ 旧代码
const exe = b.addExecutable("myapp", "src/main.zig");

// ✅ 新代码
const exe = b.addExecutable(.{
    .name = "myapp",
    .root_source_file = b.path("src/main.zig"),
});
```

### 10. `std.fs.Dir.openFile` 现在需要传递 `io` 参数

**破坏性**：所有文件系统操作都需要 `*std.Io` 实例。

**修复**：如上文 I/O 接口化示例。

### 11. `std.Io.Dir.rename` 需要 5 个参数，改用 `renameAbsolute`

**破坏性**：`std.Io.Dir.rename(old_dir, old_sub_path, new_dir, new_sub_path, io)` 需要 5 个参数。

**修复**：对于绝对路径重命名，使用 `std.Io.Dir.renameAbsolute(old_path, new_path, io)`。

```zig
// ❌ 旧代码
std.Io.Dir.cwd().rename(tmp_filename, filename) catch |err| { ... };

// ✅ 新代码
std.Io.Dir.renameAbsolute(tmp_filename, filename, io) catch |err| { ... };
```

### 12. `std.Io.Reader.readAlloc` 需要精确长度，改用 `allocRemaining`

**破坏性**：`readAlloc(allocator, len)` 会分配 `len` 字节，传入 `std.math.maxInt(usize)` 会导致 OutOfMemory。

**修复**：使用 `allocRemaining(allocator, .unlimited)` 自动读取剩余所有数据。

```zig
// ❌ 旧代码
const contents = reader.interface.readAlloc(allocator, std.math.maxInt(usize)) catch { ... };

// ✅ 新代码
const contents = reader.interface.allocRemaining(allocator, .unlimited) catch { ... };
```

### 13. `std.Io.Dir.deleteFile` 需要 `io` 参数

**破坏性**：`deleteFile(sub_path)` 不再接受单参数。

**修复**：传递 `io` 实例。

```zig
// ❌ 旧代码
dir.deleteFile(entry.name) catch {};

// ✅ 新代码
dir.deleteFile(io, entry.name) catch {};
```

### 14. `std.Io.File.writeStreamingAll` 替代 `writeAll`

**破坏性**：`file.writeAll(io, data)` 在某些上下文中不可用。

**修复**：使用 `file.writeStreamingAll(io, data)`。

```zig
// ✅ 新代码
try file.writeStreamingAll(io, data);
```

## 🤖 AI 工作流程

1. **需求理解**：优先阅读 `AGENTS.md`、`README.md`。
2. **约束检查**：
   - 确保所有阻塞 I/O 都通过传递的 `*std.Io` 参数执行。
   - 检查是否使用了已废弃的 API（如 `GeneralPurposeAllocator`, `Timer`, `linkSystemLibrary` 等）。
3. **问题定位**：
   - 善于通过 `git diff` 发现改动引入的潜在问题。
   - 必要时在对话中提问澄清约束或设计细节，避免误解导致的实现偏差。
   - 必须适配 Zig 0.16.0 的特定要求。
4. **提交前验证**：
   - 运行 `zig build test`（如果存在测试）。
   - 确保未引入未定义行为（如数组越界、空指针解引用）。
   - 检查代码格式：`zig fmt --check .`

## 🔒 禁止事项

- ❌ 在业务代码中直接调用 `@cImport` 或裸 C 函数。
- ❌ 忽略 `std.Io` 接口化要求，使用 `std.fs.cwd()` 等阻塞 API。
- ❌ 使用不安全的 `@alignCast` 或假设指针对齐。
- ❌ 删除功能代码，绕开问题。
- ❌ 在根文件中使用相对路径导入另一个根文件。
- ❌ 参数硬编码，没有从权重文件实际形状获取。
- ❌ 残留 `std.heap.GeneralPurposeAllocator` 或 `std.time.Timer`。

## 🧪 测试验证清单

完成迁移后，运行以下命令确保无误：

```bash
zig build test          # 运行单元测试
zig build               # 构建项目
zig fmt --check .       # 检查代码格式
```

如果遇到任何未列出的编译错误，请查阅 [Zig 0.16.0 发布说明](https://ziglang.org/download/0.16.0/release-notes.html) 或询问本项目维护者。

## 📚 参考材料

- [Zig 0.16.0 文档](https://ziglang.org/documentation/0.16.0/)
- [Zig 0.16.0 发布说明](https://ziglang.org/download/0.16.0/release-notes.html)

---

## 🛠️ 总体修复策略

Zig 0.16.0 的核心变更：
- **I/O 接口化**：所有阻塞 I/O 必须通过 `*std.Io` 实例。
- **分配器 API 强化**：`ArrayList` 的 `deinit` 需要传入分配器；`toOwnedSlice` 返回错误。
- **枚举/联合初始化语法**：`Io.Limit` 是 `union(enum)`，不能用结构体初始化。

建议按以下顺序修复：

1. 修复 `ArrayList` 初始化与 `deinit`
2. 修复所有 `Io` 相关调用（添加 `io` 参数）
3. 修复测试中的内存泄漏
4. 更新 `build.zig` 以适配新 API

---

## 1. 修复 `ArrayList` 初始化与 `deinit`

### 问题代码示例
```zig
var text = std.ArrayList(u8){};               // ❌ 缺少 items/capacity
var args = std.ArrayList(nodes.Expression){}; // ❌
defer list.deinit();                          // ❌ 需要分配器参数
```

### 修复方案
```zig
// ✅ 正确初始化
var text = std.ArrayList(u8).init(allocator);
var args = std.ArrayList(nodes.Expression).init(allocator);
defer text.deinit(allocator);
defer args.deinit(allocator);
```

---

## 2. 修复 `cache.zig` 中的 I/O API

### 错误 1: `Io.Limit` 初始化语法错误
```zig
// ❌ 错误
const file_data = try cwd.readFileAlloc(io, filename, allocator, .{ .max = 1024 * 1024 });
// error: type 'Io.Limit' does not support struct initialization syntax

// ✅ 正确
const file_data = try cwd.readFileAlloc(io, filename, allocator, .max = 1024 * 1024);
// 或使用 .unlimited
const file_data = try cwd.readFileAlloc(io, filename, allocator, .unlimited);
```

### 错误 2: `file.writeAll` 缺少 `io` 参数
```zig
// ❌ 错误
try file.writeAll(data);

// ✅ 正确
try file.writeAll(io, data);
```

### 错误 3: `dir.close()` 缺少 `io` 参数
```zig
// ❌ 错误
defer dir.close();

// ✅ 正确
defer dir.close(io);
```

---

## 3. 修复 `loaders.zig` 中的 I/O API

### 错误: `walker.next()` 缺少 `io` 参数
```zig
// ❌ 错误
while (walker.next() catch continue) |entry| { ... }

// ✅ 正确
while (walker.next(io) catch continue) |entry| { ... }
```

### 错误: `file.writeAll` 缺少 `io` 参数（同上）
```zig
try file.writeAll(io, content);
```

---

## 4. 修复测试文件中的 `writeAll`

在 `test/unit/loaders.zig` 中多处出现：
```zig
try file.writeAll("Hello {{ name }}!");
```
全部改为：
```zig
try file.writeAll(io, "Hello {{ name }}!");
```

**注意**：这些测试函数需要能够访问 `io` 实例。如果测试函数没有 `io` 参数，需要从 `std.process.Init` 获取：

```zig
test "example" {
    var gpa = std.testing.allocator;
    // 获取 io 实例（测试环境中可用）
    const io = std.testing.io_instance;  // 或通过 init.io 传递
}
```

但 Zig 0.16.0 测试框架默认不提供 `io`。一个实用的办法：创建辅助函数 `createTestFile`，内部使用 `std.Io.Threaded`：

```zig
fn createTestFile(allocator: std.mem.Allocator, path: []const u8, content: []const u8) !void {
    var io_thr = try std.Io.Threaded.init(allocator, .{});
    defer io_thr.deinit();
    const io = io_thr.io();

    var dir = try std.Io.Dir.cwd(io);
    defer dir.close(io);

    var file = try dir.createFile(io, path, .{});
    defer file.close(io);
    try file.writeAll(io, content);
}
```

---

## 5. 修复内存泄漏

错误信息显示 `readFileAlloc` 分配的内存没有被释放。在 `src/root.zig` 的 `test_eval` 函数中：

```zig
// 原代码
const source = try cwd.readFileAlloc(io.io(), source_path, allocator, .unlimited);
// ... 使用 source
// 没有释放 source
```

**修复**：添加 `defer allocator.free(source)`。

```zig
const source = try cwd.readFileAlloc(io.io(), source_path, allocator, .unlimited);
defer allocator.free(source);
```

**注意**：`readFileAlloc` 返回的是分配器分配的切片，必须由调用方释放。同样，其他类似分配（如 `toOwnedSlice`）也需要相应释放。

---

## 6. 更新 `parser.zig` 和 `value.zig` 中的 `ArrayList`

### 问题
`parser.zig` 中大量使用 `std.ArrayList(Node){}` 初始化，以及 `defer list.deinit()`。

### 修复模式
```zig
// ❌ 旧代码
var if_body = std.ArrayList(*nodes.Stmt){};
defer if_body.deinit();

// ✅ 新代码
var if_body = std.ArrayList(*nodes.Stmt).init(allocator);
defer if_body.deinit(allocator);
```

**需要传递 `allocator` 到解析器函数**。确保 `Parser` 结构体保存分配器：

```zig
const Parser = struct {
    allocator: std.mem.Allocator,
    // ... 其他字段

    fn parseIfStatement(self: *Parser) !Node {
        var if_body = std.ArrayList(*Node).init(self.allocator);
        defer if_body.deinit(self.allocator);
        // ...
    }
};
```

---

## 7. 更新 `build.zig`

确保链接系统库的方式正确：

```zig
// ❌ 旧代码
exe.linkSystemLibrary("c");

// ✅ 新代码
exe.root_module.linkSystemLibrary("c");
```

添加可执行文件时使用命名参数：

```zig
const exe = b.addExecutable(.{
    .name = "vibe-jinja",
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
});
```

---

## 📋 修复清单

- [x] **全局替换**：`std.ArrayList(T){}` → `std.ArrayList(T).init(allocator)`
- [x] **全局替换**：`defer list.deinit()` → `defer list.deinit(allocator)`
- [x] **全局替换**：`.{ .max = size }` → `.max = size`（用于 `Io.Limit`）
- [x] **所有 `file.writeAll(content)`** → `file.writeAll(io, content)` 或 `file.writeStreamingAll(io, content)`
- [x] **所有 `dir.close()`** → `dir.close(io)`
- [x] **所有 `walker.next()`** → `walker.next(io)`
- [x] **所有 `readFileAlloc` 返回值** → 添加 `defer allocator.free(...)`
- [x] **更新 `build.zig`** 中的 `linkSystemLibrary` 和 `addExecutable`
- [x] **`std.Io.Dir.rename`** → `std.Io.Dir.renameAbsolute`（需要 io 参数）
- [x] **`std.Io.Reader.readAlloc`** → `allocRemaining`（避免 OutOfMemory）
- [x] **`std.Io.Dir.deleteFile`** → 添加 io 参数
- [x] **`std.Io.File.writeStreamingAll`** → 替代 `writeAll` 在 cache 场景

---

## 🧪 验证步骤

完成修复后，运行：

```bash
zig build test          # 所有测试应通过且无内存泄漏
zig build               # 构建成功
zig fmt --check .       # 格式正确
```

如果仍有错误，根据新的编译提示继续调整。迁移到 Zig 0.16.0 需要耐心处理所有 I/O 相关 API 的签名变化。

---

**AI 助手应始终以"安全、可维护、高性能"为原则，优先遵循本文档约束。如有歧义，请在对话中提问澄清。**
