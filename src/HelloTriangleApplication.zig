const vk = @import("vulkan");
const c = @import("c");
const std = @import("std");
const glfw = @import("glfw.zig");

const Allocator = std.mem.Allocator;

const HelloTriangleApplication = @This();

width: c_int = 800,
height: c_int = 600,
window: *c.GLFWwindow = undefined,
instance: vk.Instance = undefined,
base_wrapper: vk.BaseWrapper = undefined,

pub fn run(self: *HelloTriangleApplication, allocator: Allocator) !void {
    try self.initWindow();
    try self.initVulkan(allocator);
    defer self.cleanup();

    try self.mainLoop();
}

fn initVulkan(self: *HelloTriangleApplication, allocator: Allocator) !void {
    try self.createInstance(allocator);
}

fn createInstance(self: *HelloTriangleApplication, allocator: Allocator) !void {

    // We need this because Vulkan dynamically loads all the functions it has access to depending on the system.
    self.base_wrapper = vk.BaseWrapper.load(glfw.getInstanceProcAddress);

    var glfw_extension_count: u32 = 0;
    const glfw_extensions = glfw.getRequiredInstanceExtensions(&glfw_extension_count);

    const vk_properties = try self.base_wrapper.enumerateInstanceExtensionPropertiesAlloc(null, allocator);

    for (glfw_extensions.?[0..glfw_extension_count]) |glfw_ext| {
        std.debug.print("Required GLFW Extension: {s} -- ", .{glfw_ext});
        for (vk_properties) |vk_prop| {
            if ( eq_block: {
                // since vk_prop.extension name is a 256-long char array we have to convert it to a slice.
                // The following comment is another way of doing the same thing.
                // const vk_prop_name = std.mem.sliceTo(&vk_prop.extension_name, 0);
                const vk_prop_name = std.mem.span(@as([*:0]const u8, @ptrCast(&vk_prop.extension_name)));
                const glfw_ext_name = std.mem.span(glfw_ext);
                //std.debug.print("Equality: {s} == {s} = ", .{vk_prop_name, glfw_ext_name});
                const res = std.mem.eql(u8, vk_prop_name, glfw_ext_name);
                //std.debug.print("{}\n", .{res});
                break :eq_block res;
            }) {
                std.debug.print("Found!\n", .{});
                break;
            }
        } else {
            std.debug.print("Missing!\n", .{});
            return error.UnsupportedGlfwExtension;
        }
    }

    const create_info = vk.InstanceCreateInfo{
        .p_application_info = &vk.ApplicationInfo{
            .p_application_name = "Hello Triangle",
            .application_version = vk.makeApiVersion(0, 1, 0, 0).toU32(),
            .p_engine_name = "No engine",
            .engine_version = vk.makeApiVersion(0, 1, 0, 0).toU32(),
            .api_version = vk.API_VERSION_1_4.toU32(),
        },
        .enabled_extension_count = glfw_extension_count,
        .pp_enabled_extension_names = glfw_extensions,
    };

    self.instance = try self.base_wrapper.createInstance(&create_info, null);
}

fn initWindow(self: *HelloTriangleApplication) !void {
    //if (c.glfwPlatformSupported(c.GLFW_PLATFORM_WAYLAND) == 1) {
    //    c.glfwInitHint(c.GLFW_PLATFORM, c.GLFW_PLATFORM_WAYLAND);
    //}
    if (c.glfwInit() != c.GLFW_TRUE) return error.GlfwInitFailed;
    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);
    self.window = c.glfwCreateWindow(self.width, self.height, "Vulkan", null, null) orelse return error.GlfwCreateWindowFailed;
}

fn mainLoop(self: *HelloTriangleApplication) !void {
    while(c.glfwWindowShouldClose(self.window) == 0) {
        c.glfwPollEvents();
    }
}

fn cleanup(self: *HelloTriangleApplication) void {
    c.glfwDestroyWindow(self.window);
    c.glfwTerminate();
}
