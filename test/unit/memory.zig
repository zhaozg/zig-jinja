//! Memory leak reproduction tests based on mem.md findings.
//!
//! These tests reproduce the leaks identified when running `zig build test-jinja`
//! from the parent zllama.zig project:
//!   - 'test_jinja.test.jinja: string concat ~'
//!   - 'test_jinja.test.jinja: is divisibleby'
//!   - 'test_jinja.test.jinja: is defined test'
//!   - 'test_jinja.test.jinja: is undefined test'
//!
//! Each leaks 2 allocations:
//!   1. allocator.dupe(u8, input) in unescapeString (nodes.zig:1377)
//!   2. allocator.create(nodes.StringLiteral) in parseStringLiteral (parser.zig:1323)

const std = @import("std");
const testing = std.testing;
const vibe_jinja = @import("vibe_jinja");
const environment = vibe_jinja.environment;
const parser = vibe_jinja.parser;
const lexer = vibe_jinja.lexer;
const nodes = vibe_jinja.nodes;
const runtime = vibe_jinja.runtime;
const value = vibe_jinja.value;

// Reproduce: string literal in 'is defined' expression.
test "memory: string literal in 'is defined' expression" {
    const allocator = std.testing.allocator;

    var env = environment.Environment.init(allocator);
    defer env.deinit();

    var rt = runtime.Runtime.init(&env, allocator);
    defer rt.deinit();

    const source = "{{ 'hello' is defined }}";
    var vars = std.StringHashMap(value.Value).init(allocator);
    defer vars.deinit();

    const result = try rt.renderString(source, vars, "memory_is_defined");
    defer allocator.free(result);

    try testing.expectEqualStrings("true", result);
}

// Reproduce: string literal in 'is undefined' test.
test "memory: string literal in 'is undefined' expression" {
    const allocator = std.testing.allocator;

    var env = environment.Environment.init(allocator);
    defer env.deinit();

    var rt = runtime.Runtime.init(&env, allocator);
    defer rt.deinit();

    const source = "{{ 'hello' is undefined }}";
    var vars = std.StringHashMap(value.Value).init(allocator);
    defer vars.deinit();

    const result = try rt.renderString(source, vars, "memory_is_undefined");
    defer allocator.free(result);

    try testing.expectEqualStrings("false", result);
}

// Reproduce: is divisibleby expression.
test "memory: is divisibleby expression" {
    const allocator = std.testing.allocator;

    var env = environment.Environment.init(allocator);
    defer env.deinit();

    var rt = runtime.Runtime.init(&env, allocator);
    defer rt.deinit();

    const source = "{{ 10 is divisibleby(5) }}";
    var vars = std.StringHashMap(value.Value).init(allocator);
    defer vars.deinit();

    const result = try rt.renderString(source, vars, "memory_divisibleby");
    defer allocator.free(result);

    try testing.expectEqualStrings("true", result);
}

// Reproduce: string concatenation with ~ operator.
test "memory: string concat with ~ operator" {
    const allocator = std.testing.allocator;

    var env = environment.Environment.init(allocator);
    defer env.deinit();

    var rt = runtime.Runtime.init(&env, allocator);
    defer rt.deinit();

    const source = "{{ \"hello \" ~ \"world\" }}";
    var vars = std.StringHashMap(value.Value).init(allocator);
    defer vars.deinit();

    const result = try rt.renderString(source, vars, "memory_concat");
    defer allocator.free(result);

    try testing.expectEqualStrings("hello world", result);
}

// Direct parse/deinit test.
test "memory: direct parse and deinit string literal" {
    const allocator = std.testing.allocator;

    var env = environment.Environment.init(allocator);
    defer env.deinit();

    // Tokenize
    var lex = lexer.Lexer.init(&env, "{{ 'hello' }}", "memory_direct");
    const stream = try lex.tokenize(allocator);
    defer allocator.free(stream.tokens);

    // Parse
    var p = parser.Parser.init(&env, stream, "memory_direct", allocator);
    const template = try p.parse();
    defer {
        template.deinit(allocator);
        allocator.destroy(template);
    }

    // Verify the template has a body with an Output node containing our string
    try testing.expectEqual(@as(usize, 1), template.body.items.len);

    const output = @as(*nodes.Output, @ptrCast(@alignCast(template.body.items[0])));
    try testing.expectEqual(@as(usize, 1), output.nodes.items.len);

    // Verify it's a string literal with value "hello"
    const expr = output.nodes.items[0];
    try testing.expect(expr == .string_literal);
    try testing.expectEqualStrings("hello", expr.string_literal.value);
}

// Test: string literal with filter.
test "memory: string literal with filter" {
    const allocator = std.testing.allocator;

    var env = environment.Environment.init(allocator);
    defer env.deinit();

    var rt = runtime.Runtime.init(&env, allocator);
    defer rt.deinit();

    const source = "{{ 'hello' | upper }}";
    var vars = std.StringHashMap(value.Value).init(allocator);
    defer vars.deinit();

    const result = try rt.renderString(source, vars, "memory_filter");
    defer allocator.free(result);

    try testing.expectEqualStrings("HELLO", result);
}

// Test: parse and deinit a concat expression.
test "memory: direct parse and deinit concat expression" {
    const allocator = std.testing.allocator;

    var env = environment.Environment.init(allocator);
    defer env.deinit();

    // Tokenize a concat expression
    var lex = lexer.Lexer.init(&env, "{{ 'hello ' ~ 'world' }}", "memory_concat_direct");
    const stream = try lex.tokenize(allocator);
    defer allocator.free(stream.tokens);

    // Parse
    var p = parser.Parser.init(&env, stream, "memory_concat_direct", allocator);
    const template = try p.parse();
    defer {
        template.deinit(allocator);
        allocator.destroy(template);
    }

    // Verify template has body
    try testing.expect(template.body.items.len >= 1);
}
