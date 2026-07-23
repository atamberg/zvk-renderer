const vk = @import("vulkan");
const c = @import("c");
const std = @import("std");

const width = 800;
const height = 600;

var window: ?*c.GLFWwindow = null;

pub fn run() !void {
    try initWindow();
    try initVulkan();
    defer cleanup();

    try mainLoop();
}

fn initVulkan() !void {

}

fn initWindow() !void {
    //if (c.glfwPlatformSupported(c.GLFW_PLATFORM_WAYLAND) == 1) {
    //    c.glfwInitHint(c.GLFW_PLATFORM, c.GLFW_PLATFORM_WAYLAND);
    //}
    if (c.glfwInit() != c.GLFW_TRUE) return error.GlfwInitFailed;
    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);
    window = c.glfwCreateWindow(width, height, "Vulkan", null, null);
}

fn mainLoop() !void {
    while(c.glfwWindowShouldClose(window) == 0) {
        c.glfwPollEvents();
    }
}

fn cleanup() void {
    c.glfwDestroyWindow(window);
    c.glfwTerminate();
}
