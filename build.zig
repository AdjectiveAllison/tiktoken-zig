const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build tiktoken-c (Rust library)
    const tiktoken_c = b.addSystemCommand(&[_][]const u8{
        "cargo",                 "build", "--release", "--manifest-path",
        "tiktoken-c/Cargo.toml",
    });

    const rust_lib = b.addStaticLibrary(.{
        .name = "tiktoken-c",
        .target = target,
        .optimize = optimize,
    });
    rust_lib.step.dependOn(&tiktoken_c.step);

    // Add the rust library
    const rust_lib_path = "tiktoken-c/target/release/libtiktoken_c.a";
    rust_lib.addObjectFile(b.path(rust_lib_path));

    // Link necessary system libraries
    rust_lib.linkSystemLibrary("c");
    rust_lib.linkSystemLibrary("gcc_s");
    rust_lib.linkLibC();

    // Create the module
    const tiktoken_mod = b.addModule("tiktoken-zig", .{
        .root_source_file = b.path("src/tiktoken.zig"),
    });

    tiktoken_mod.linkLibrary(rust_lib);
    // Create the tests
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/tiktoken.zig"),
        .target = target,
        .optimize = optimize,
    });

    main_tests.addIncludePath(b.path("tiktoken-c"));
    main_tests.addObjectFile(b.path(rust_lib_path));
    main_tests.linkSystemLibrary("c");
    main_tests.linkSystemLibrary("gcc_s");
    main_tests.linkLibC();

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // Add this module to the build
    b.modules.put("tiktoken", tiktoken_mod) catch @panic("OOM");
}
