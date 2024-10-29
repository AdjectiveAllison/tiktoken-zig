const std = @import("std");
const c = @cImport({
    @cInclude("tiktoken.h");
});

pub const CoreBPE = opaque {};

pub const FunctionCall = struct {
    name: []const u8,
    arguments: []const u8,
};

pub const ChatCompletionRequestMessage = struct {
    role: []const u8,
    content: ?[]const u8,
    name: ?[]const u8,
    function_call: ?FunctionCall,
};

pub const Encoding = struct {
    corebpe: *CoreBPE,

    const Self = @This();

    pub fn init(model_name: []const u8) !Self {
        const corebpe = c.tiktoken_get_bpe_from_model(model_name.ptr) orelse return error.FailedToGetBPE;
        return Self{ .corebpe = @as(*CoreBPE, @ptrCast(corebpe)) };
    }

    pub fn deinit(self: *Self) void {
        c.tiktoken_destroy_corebpe(@as(*c.CoreBPE, @ptrCast(self.corebpe)));
    }

    pub fn encodeOrdinary(self: *Self, text: []const u8) ![]u32 {
        var num_tokens: usize = 0;
        const tokens_ptr = c.tiktoken_corebpe_encode_ordinary(@as(*c.CoreBPE, @ptrCast(self.corebpe)), text.ptr, &num_tokens);
        if (tokens_ptr == null) return error.EncodingFailed;
        defer std.c.free(tokens_ptr);

        const result = try std.heap.c_allocator.alloc(u32, num_tokens);
        @memcpy(result, tokens_ptr[0..num_tokens]);
        return result;
    }

    pub fn encode(self: *Self, text: []const u8, allowed_special: []const []const u8) ![]u32 {
        var num_tokens: usize = 0;
        var c_allowed_special = try std.heap.c_allocator.alloc([*c]const u8, allowed_special.len);
        defer std.heap.c_allocator.free(c_allowed_special);

        for (allowed_special, 0..) |special, i| {
            c_allowed_special[i] = special.ptr;
        }

        const tokens_ptr = c.tiktoken_corebpe_encode(@as(*c.CoreBPE, @ptrCast(self.corebpe)), text.ptr, c_allowed_special.ptr, allowed_special.len, &num_tokens);
        if (tokens_ptr == null) return error.EncodingFailed;
        defer std.c.free(tokens_ptr);

        const result = try std.heap.c_allocator.alloc(u32, num_tokens);
        @memcpy(result, tokens_ptr[0..num_tokens]);
        return result;
    }

    pub fn encodeWithSpecialTokens(self: *Self, text: []const u8) ![]u32 {
        var num_tokens: usize = 0;
        const tokens_ptr = c.tiktoken_corebpe_encode_with_special_tokens(@as(*c.CoreBPE, @ptrCast(self.corebpe)), text.ptr, &num_tokens);
        if (tokens_ptr == null) return error.EncodingFailed;
        defer std.c.free(tokens_ptr);

        const result = try std.heap.c_allocator.alloc(u32, num_tokens);
        @memcpy(result, tokens_ptr[0..num_tokens]);
        return result;
    }

    pub fn decode(self: *Self, tokens: []const u32) ![]u8 {
        const decoded_ptr = c.tiktoken_corebpe_decode(@as(*c.CoreBPE, @ptrCast(self.corebpe)), tokens.ptr, tokens.len);
        if (decoded_ptr == null) return error.DecodingFailed;
        defer std.c.free(decoded_ptr);

        const decoded_len = std.mem.len(decoded_ptr);
        const result = try std.heap.c_allocator.alloc(u8, decoded_len);
        @memcpy(result, decoded_ptr[0..decoded_len]);
        return result;
    }
};

pub fn encodingForModel(model_name: []const u8) !Encoding {
    return Encoding.init(model_name);
}

pub fn getCompletionMaxTokens(model: []const u8, prompt: []const u8) usize {
    return c.tiktoken_get_completion_max_tokens(model.ptr, prompt.ptr);
}

pub fn numTokensFromMessages(model: []const u8, messages: []const ChatCompletionRequestMessage) !usize {
    var c_messages = try std.heap.c_allocator.alloc(c.CChatCompletionRequestMessage, messages.len);
    defer std.heap.c_allocator.free(c_messages);

    for (messages, 0..) |msg, i| {
        c_messages[i] = c.CChatCompletionRequestMessage{
            .role = msg.role.ptr,
            .content = if (msg.content) |content| content.ptr else null,
            .name = if (msg.name) |name| name.ptr else null,
            .function_call = if (msg.function_call) |fc| &c.CFunctionCall{
                .name = fc.name.ptr,
                .arguments = fc.arguments.ptr,
            } else null,
        };
    }

    const result = c.tiktoken_num_tokens_from_messages(model.ptr, @as(u32, @intCast(messages.len)), c_messages.ptr);
    if (result == std.math.maxInt(usize)) return error.TokenizationFailed;
    return result;
}

pub fn getChatCompletionMaxTokens(model: []const u8, messages: []const ChatCompletionRequestMessage) !usize {
    var c_messages = try std.heap.c_allocator.alloc(c.CChatCompletionRequestMessage, messages.len);
    defer std.heap.c_allocator.free(c_messages);

    for (messages, 0..) |msg, i| {
        c_messages[i] = c.CChatCompletionRequestMessage{
            .role = msg.role.ptr,
            .content = if (msg.content) |content| content.ptr else null,
            .name = if (msg.name) |name| name.ptr else null,
            .function_call = if (msg.function_call) |fc| &c.CFunctionCall{
                .name = fc.name.ptr,
                .arguments = fc.arguments.ptr,
            } else null,
        };
    }

    const result = c.tiktoken_get_chat_completion_max_tokens(model.ptr, @as(u32, @intCast(messages.len)), c_messages.ptr);
    if (result == std.math.maxInt(usize)) return error.MaxTokensCalculationFailed;
    return result;
}

pub fn tiktokenCVersion() []const u8 {
    return std.mem.span(c.tiktoken_c_version());
}

test "basic functionality" {
    var encoding = try encodingForModel("gpt-4");
    defer encoding.deinit();

    const text = "Hello, world!";
    const encoded = try encoding.encodeWithSpecialTokens(text);
    defer std.heap.c_allocator.free(encoded);

    try std.testing.expect(encoded.len > 0);

    const decoded = try encoding.decode(encoded);
    defer std.heap.c_allocator.free(decoded);

    try std.testing.expectEqualStrings(text, decoded);
}

test "chat completion max tokens" {
    const model = "gpt-3.5-turbo";
    const messages = [_]ChatCompletionRequestMessage{
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

    const max_tokens = try getChatCompletionMaxTokens(model, &messages);
    try std.testing.expect(max_tokens > 0);
}

test "num tokens from messages" {
    const model = "gpt-4";
    const messages = [_]ChatCompletionRequestMessage{
        .{
            .role = "system",
            .content = "You are a helpful assistant that only speaks French.",
            .name = null,
            .function_call = null,
        },
        .{
            .role = "user",
            .content = "Hello, how are you?",
            .name = null,
            .function_call = null,
        },
        .{
            .role = "assistant",
            .content = "Parlez-vous francais?",
            .name = null,
            .function_call = null,
        },
    };

    const num_tokens = try numTokensFromMessages(model, &messages);
    try std.testing.expectEqual(@as(usize, 36), num_tokens);
}

test "tiktoken c version" {
    const version = tiktokenCVersion();
    try std.testing.expect(version.len > 0);
}
