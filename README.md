# tiktoken-zig

Zig bindings for [tiktoken-c](https://github.com/kojix2/tiktoken-c), providing fast BPE tokenization for OpenAI models.

## Features

- Complete Zig bindings for the tiktoken-c library
- Support for all OpenAI tokenizer models (GPT-3.5, GPT-4, etc.)
- Token counting for chat completions
- Zero-copy token encoding/decoding where possible
- Idiomatic Zig error handling and memory management

## Installation

1. Declare tiktoken-zig as a project dependency with `zig fetch`:

    ```sh
    # latest version
    zig fetch --save git+https://github.com/AdjectiveAllison/tiktoken-zig.git#main

    # specific commit
    zig fetch --save git+https://github.com/AdjectiveAllison/tiktoken-zig.git#COMMIT
    ```

2. Expose tiktoken-zig as a module in your project's `build.zig`:

    ```zig
    pub fn build(b: *std.Build) void {
        const target = b.standardTargetOptions(.{});
        const optimize = b.standardOptimizeOption(.{});

        const opts = .{ .target = target, .optimize = optimize };   // 👈
        const tiktoken_zig = b.dependency("tiktoken-zig", opts).module("tiktoken-zig"); // 👈

        const exe = b.addExecutable(.{
            .name = "my-project",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        exe.root_module.addImport("tiktoken-zig", tiktoken_zig); // 👈

        // ...
    }
    ```

3. Import TikToken Zig into your code:

    ```zig
    const tiktoken = @import("tiktoken-zig");
    ```

## Usage

Basic token encoding/decoding:

```zig
const std = @import("std");
const tiktoken = @import("tiktoken-zig");

pub fn main() !void {
    // Initialize an encoder for GPT-4
    var encoding = try tiktoken.encodingForModel("gpt-4");
    defer encoding.deinit();

    // Encode text to tokens
    const text = "Hello, world!";
    const tokens = try encoding.encodeOrdinary(text);
    defer std.heap.c_allocator.free(tokens);

    // Decode tokens back to text
    const decoded = try encoding.decode(tokens);
    defer std.heap.c_allocator.free(decoded);

    std.debug.print("Original: {s}\nDecoded: {s}\n", .{ text, decoded });
}
```

Using specific base models:

```zig
// Use cl100k_base directly (used by GPT-3.5-turbo, GPT-4)
var encoding = try tiktoken.cl100kBase();
defer encoding.deinit();

// Other available base models:
// try tiktoken.r50kBase()    - GPT-2
// try tiktoken.p50kBase()    - GPT-3
// try tiktoken.p50kEdit()    - Code editing models
// try tiktoken.o200kBase()   - Code completion models
```

Counting tokens for chat completions:

```zig
const messages = [_]tiktoken.ChatCompletionRequestMessage{
    .{
        .role = "system",
        .content = "You are a helpful assistant.",
        .name = null,
        .function_call = null,
    },
    .{
        .role = "user",
        .content = "Hello!",
        .name = null,
        .function_call = null,
    },
};

// Get token count for messages
const num_tokens = try tiktoken.numTokensFromMessages("gpt-4", &messages);

// Get maximum tokens for completion
const max_tokens = try tiktoken.getChatCompletionMaxTokens("gpt-4", &messages);
```

## Building

Requirements:
- Zig 0.13.0 or newer
- Rust (for building tiktoken-c)
- C compiler

Build the library:
```bash
git clone https://github.com/AdjectiveAllison/tiktoken-zig
cd tiktoken-zig
zig build
```

Run tests:
```bash
zig build test
```

## API Reference

### Types

```zig
pub const Encoding = struct {
    // Main encoding/decoding methods
    pub fn encodeOrdinary(self: *Self, text: []const u8) ![]u32
    pub fn encode(self: *Self, text: []const u8, allowed_special: []const []const u8) ![]u32
    pub fn encodeWithSpecialTokens(self: *Self, text: []const u8) ![]u32
    pub fn decode(self: *Self, tokens: []const u32) ![]u8
};

pub const ChatCompletionRequestMessage = struct {
    role: []const u8,
    content: ?[]const u8,
    name: ?[]const u8,
    function_call: ?FunctionCall,
};

pub const FunctionCall = struct {
    name: []const u8,
    arguments: []const u8,
};
```

### Functions

```zig
// Model-specific encoders
pub fn encodingForModel(model_name: []const u8) !Encoding
pub fn r50kBase() !Encoding
pub fn p50kBase() !Encoding
pub fn p50kEdit() !Encoding
pub fn cl100kBase() !Encoding
pub fn o200kBase() !Encoding

// Token counting
pub fn getCompletionMaxTokens(model: []const u8, prompt: []const u8) u32
pub fn numTokensFromMessages(model: []const u8, messages: []const ChatCompletionRequestMessage) !usize
pub fn getChatCompletionMaxTokens(model: []const u8, messages: []const ChatCompletionRequestMessage) !usize

// Utility functions
pub fn tiktokenCVersion() []const u8
pub fn initLogger() void
```

## License

MIT License (same as tiktoken-c) tiktoken-zig
