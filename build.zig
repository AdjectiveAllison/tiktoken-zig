const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "tiktoken-zig",
        .root_source_file = b.path("src/tiktoken.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Build tiktoken-c (Rust library)
    const tiktoken_c = b.addSystemCommand(&[_][]const u8{
        "cargo",                 "build", "--release", "--manifest-path",
        "tiktoken-c/Cargo.toml",
    });

    // Add tiktoken-c as a dependency
    lib.step.dependOn(&tiktoken_c.step);

    // Add the path to the compiled Rust library
    const rust_lib_path = "tiktoken-c/target/release/libtiktoken_c.a";
    lib.addObjectFile(b.path(rust_lib_path));

    // Add include directory for tiktoken.h
    lib.addIncludePath(b.path("tiktoken-c"));

    // Link necessary system libraries
    lib.linkSystemLibrary("c");
    lib.linkSystemLibrary("gcc_s");
    lib.linkLibC();

    // Add link flags for exception handling
    // lib.addLibraryPath(b.path("/usr/lib/gcc/x86_64-linux-gnu/11")); // Adjust this path if necessary
    // lib.linkSystemLibrary("gcc");

    b.installArtifact(lib);

    // Tests
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
    // main_tests.addLibraryPath(b.path("/usr/lib/gcc/x86_64-linux-gnu/11")); // Adjust this path if necessary
    // main_tests.linkSystemLibrary("gcc");

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
