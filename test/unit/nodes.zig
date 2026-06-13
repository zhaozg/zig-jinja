const std = @import("std");
const testing = std.testing;
const vibe_jinja = @import("vibe_jinja");
const nodes = vibe_jinja.nodes;
const value = vibe_jinja.value;
const context = vibe_jinja.context;

test "node string literal init and deinit" {
    const allocator = std.testing.allocator;

    var str_lit = try nodes.StringLiteral.init(allocator, "hello", 1, "test.jinja");
    defer str_lit.deinit(allocator);

    try testing.expectEqualStrings("hello", str_lit.value);
    try testing.expect(str_lit.base.lineno == 1);
}

test "node integer literal init and deinit" {
    const allocator = std.testing.allocator;

    var int_lit = nodes.IntegerLiteral.init(1, "test.jinja", 42);
    defer int_lit.deinit(allocator);

    try testing.expect(int_lit.value == 42);
    try testing.expect(int_lit.base.lineno == 1);
}

test "node boolean literal init and deinit" {
    const allocator = std.testing.allocator;

    var bool_lit = nodes.BooleanLiteral.init(1, "test.jinja", true);
    defer bool_lit.deinit(allocator);

    try testing.expect(bool_lit.value == true);
    try testing.expect(bool_lit.base.lineno == 1);
}

test "node float literal init and deinit" {
    const allocator = std.testing.allocator;

    var float_lit = nodes.FloatLiteral.init(1, "test.jinja", 3.14);
    defer float_lit.deinit(allocator);

    try testing.expect(float_lit.value == 3.14);
    try testing.expect(float_lit.base.lineno == 1);
}

test "node null literal init and deinit" {
    const allocator = std.testing.allocator;

    var null_lit = nodes.NullLiteral.init(1, "test.jinja");
    defer null_lit.deinit(allocator);

    try testing.expect(null_lit.base.lineno == 1);
}

test "node name init and deinit" {
    const allocator = std.testing.allocator;

    var name_node = try nodes.Name.init(allocator, "myvar", .load, 1, "test.jinja");
    defer name_node.deinit(allocator);

    try testing.expectEqualStrings("myvar", name_node.name);
    try testing.expect(name_node.ctx == .load);
}

test "node template init and deinit" {
    const allocator = std.testing.allocator;

    var template = nodes.Template.init(allocator, 1, "test.jinja");
    defer template.deinit(allocator);

    try testing.expect(template.name == null);
    try testing.expect(template.body.items.len == 0);
}

test "node output plain text init and deinit" {
    const allocator = std.testing.allocator;

    var output = try nodes.Output.initPlainText(allocator, "hello world", 1, "test.jinja");
    defer output.deinit(allocator);

    try testing.expectEqualStrings("hello world", output.content);
    try testing.expect(output.base.base.lineno == 1);
}

test "node output expression init and deinit" {
    const allocator = std.testing.allocator;

    var output = nodes.Output.initExpression(allocator, 1, "test.jinja");
    defer output.deinit(allocator);

    try testing.expect(output.base.base.lineno == 1);
    try testing.expect(output.nodes.items.len == 0);
}

test "node block statement init and deinit" {
    const allocator = std.testing.allocator;

    var block = try nodes.Block.init(allocator, "content", 1, "test.jinja");
    defer block.deinit(allocator);

    try testing.expectEqualStrings("content", block.name);
    try testing.expect(block.base.base.lineno == 1);
    try testing.expect(block.body.items.len == 0);
}

test "node macro init and deinit" {
    const allocator = std.testing.allocator;

    var macro = try nodes.Macro.init(allocator, "test_macro", 1, "test.jinja");
    defer macro.deinit(allocator);

    try testing.expectEqualStrings("test_macro", macro.name);
    try testing.expect(macro.base.base.lineno == 1);
    try testing.expect(macro.args.items.len == 0);
    try testing.expect(macro.body.items.len == 0);
}

test "node with init and deinit" {
    const allocator = std.testing.allocator;

    var with_stmt = nodes.With.init(allocator, 1, "test.jinja");
    defer with_stmt.deinit(allocator);

    try testing.expect(with_stmt.base.base.lineno == 1);
}

test "node comment stmt init and deinit" {
    const allocator = std.testing.allocator;

    var comment = nodes.CommentStmt.init(1, "test.jinja");
    defer comment.deinit(allocator);

    try testing.expect(comment.base.base.lineno == 1);
}

test "node continue stmt init and deinit" {
    const allocator = std.testing.allocator;

    var continue_stmt = nodes.ContinueStmt.init(1, "test.jinja");
    defer continue_stmt.deinit(allocator);

    try testing.expect(continue_stmt.base.base.lineno == 1);
}

test "node break stmt init and deinit" {
    const allocator = std.testing.allocator;

    var break_stmt = nodes.BreakStmt.init(1, "test.jinja");
    defer break_stmt.deinit(allocator);

    try testing.expect(break_stmt.base.base.lineno == 1);
}

test "node debug stmt init and deinit" {
    const allocator = std.testing.allocator;

    var debug_stmt = nodes.DebugStmt.init(1, "test.jinja");
    defer debug_stmt.deinit(allocator);

    try testing.expect(debug_stmt.base.base.lineno == 1);
}

test "node context reference init and deinit" {
    const allocator = std.testing.allocator;

    var ctx_ref = nodes.ContextReference.init(1, "test.jinja");
    defer ctx_ref.deinit(allocator);

    try testing.expect(ctx_ref.base.lineno == 1);
}

test "node derived context reference init and deinit" {
    const allocator = std.testing.allocator;

    var derived_ctx_ref = nodes.DerivedContextReference.init(1, "test.jinja");
    defer derived_ctx_ref.deinit(allocator);

    try testing.expect(derived_ctx_ref.base.lineno == 1);
}

test "node internal name init and deinit" {
    const allocator = std.testing.allocator;

    var internal_name = try nodes.InternalName.init(allocator, "__internal", 1, "test.jinja");
    defer internal_name.deinit(allocator);

    try testing.expectEqualStrings("__internal", internal_name.name);
}

test "node imported name init and deinit" {
    const allocator = std.testing.allocator;

    var imported_name = try nodes.ImportedName.init(allocator, "my_import", 1, "test.jinja");
    defer imported_name.deinit(allocator);

    try testing.expectEqualStrings("my_import", imported_name.importname);
}

test "node environment attribute init and deinit" {
    const allocator = std.testing.allocator;

    var env_attr = try nodes.EnvironmentAttribute.init(allocator, "my_attr", 1, "test.jinja");
    defer env_attr.deinit(allocator);

    try testing.expectEqualStrings("my_attr", env_attr.name);
}

test "node extension attribute init and deinit" {
    const allocator = std.testing.allocator;

    var ext_attr = try nodes.ExtensionAttribute.init(allocator, "my_ext", "my_attr", 1, "test.jinja");
    defer ext_attr.deinit(allocator);

    try testing.expectEqualStrings("my_ext", ext_attr.identifier);
    try testing.expectEqualStrings("my_attr", ext_attr.name);
}

test "node nsref init and deinit" {
    const allocator = std.testing.allocator;

    var nsref = try nodes.NSRef.init(allocator, "namespace", "attr", 1, "test.jinja");
    defer nsref.deinit(allocator);

    try testing.expectEqualStrings("namespace", nsref.name);
    try testing.expectEqualStrings("attr", nsref.attr);
}

test "node concat init and deinit" {
    const allocator = std.testing.allocator;

    var concat = nodes.Concat.init(allocator, 1, "test.jinja");
    defer concat.deinit(allocator);

    try testing.expect(concat.base.lineno == 1);
    try testing.expect(concat.nodes.items.len == 0);
}

test "node slice init and deinit" {
    const allocator = std.testing.allocator;

    var slice = nodes.Slice.init(null, null, null, 1, "test.jinja");
    defer slice.deinit(allocator);

    try testing.expect(slice.base.lineno == 1);
}

test "node list literal init and deinit" {
    const allocator = std.testing.allocator;

    var list_lit = nodes.ListLiteral.init(1, "test.jinja");
    defer list_lit.deinit(allocator);

    try testing.expect(list_lit.base.lineno == 1);
    try testing.expect(list_lit.elements.items.len == 0);
}
