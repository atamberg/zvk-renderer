const vk = @import("vulkan");
const c = @import("c");
const std = @import("std");
const glfw = @import("glfw.zig");
const options = @import("options");


const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const HelloTriangleApplication = @This();

const width = 800;
const height = 600;
const validation_layers: []const []const u8 = &.{
    "VK_LAYER_KHRONOS_validation",
};
const required_device_extensions: []const []const u8 = &.{
    vk.extensions.khr_swapchain.name,
};

window: *c.GLFWwindow = undefined,
instance: vk.InstanceProxy = undefined,
debug_messager: vk.DebugUtilsMessengerEXT = undefined,
base_wrapper: vk.BaseWrapper = undefined,
physical_device: vk.PhysicalDevice = undefined,

pub fn run(self: *HelloTriangleApplication, allocator: Allocator) !void {
    try self.initWindow();
    try self.initVulkan(allocator);
    defer self.cleanup();

    try self.mainLoop();
}

fn initVulkan(self: *HelloTriangleApplication, allocator: Allocator) !void {
    try self.createInstance(allocator);
    try self.setupDebugMessenger();
    try self.pickPhysicalDevice(allocator);
}

fn pickPhysicalDevice(self: *HelloTriangleApplication, allocator: Allocator) !void {
    const physical_devices = try self.instance.enumeratePhysicalDevicesAlloc(allocator);
    defer allocator.free(physical_devices);
    if (physical_devices.len == 0) {
        std.debug.print("Failed to find GPU with Vulkan Support!", .{});
        return error.NoGpuFound;
    }

    self.physical_device = for (physical_devices) |p_device| {
        if (try isDeviceSuitable(self.instance, p_device, allocator)) {
            break p_device;
        }
    } else return error.NoGpuFound;
}

fn isDeviceSuitable(instance: vk.InstanceProxy, p_device: vk.PhysicalDevice, allocator: Allocator) !bool {
    const device_properties = instance.getPhysicalDeviceProperties(p_device);
    //const device_features = instance.getPhysicalDeviceFeatures(p_device);
    const queue_families = try instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(p_device, allocator);
    defer allocator.free(queue_families);

    const supports_graphics = for (queue_families) |q_family| {
        if (q_family.queue_flags.graphics_bit) break true;
    } else false;

    const supports_vulkan_1_3 = device_properties.api_version >= vk.API_VERSION_1_3.toU32();

    const available_device_extensions = try instance.enumerateDeviceExtensionPropertiesAlloc(p_device, null, allocator);
    defer allocator.free(available_device_extensions);

    var supports_all_required_extensions = true;
    for (required_device_extensions) |extension| {
        supports_all_required_extensions &= for (available_device_extensions) |available_ext| {
            const available_ext_name = std.mem.span(@as([*:0]const u8, @ptrCast(&available_ext.extension_name)));
            if (std.mem.eql(u8, available_ext_name, extension)) {
                break true;
            }
        } else {
            std.debug.print("Required device extension not supported: {s}\n", .{extension});
            return false;
        };
    }


    var features = vk.PhysicalDeviceFeatures2{ .features = instance.getPhysicalDeviceFeatures(p_device) };
    instance.getPhysicalDeviceFeatures2(p_device, &features);

    var supports_required_features = true;

    var it_or_null = features.p_next;
    while (it_or_null) |it| {
        const it_pdev2 = @as(*vk.PhysicalDeviceFeatures2, @alignCast(@ptrCast(it)));
        const supports_feature = switch (it_pdev2.s_type) {
            .physical_device_vulkan_1_1_features => @as(*vk.PhysicalDeviceVulkan11Features, @alignCast(@ptrCast(it))).shader_draw_parameters,
            .physical_device_vulkan_1_3_features => @as(*vk.PhysicalDeviceVulkan13Features, @alignCast(@ptrCast(it))).dynamic_rendering,
            .physical_device_extended_dynamic_state_features_ext => @as(*vk.PhysicalDeviceExtendedDynamicStateFeaturesEXT, @alignCast(@ptrCast(it))).extended_dynamic_state,
            else => .true,
        };
        supports_required_features = if (supports_required_features and supports_feature == .true) true else false;
        it_or_null = it_pdev2.p_next;
    }
    return supports_graphics and supports_vulkan_1_3 and supports_all_required_extensions and supports_required_features;
}

fn createInstance(self: *HelloTriangleApplication, allocator: Allocator) !void {

    // We need this because Vulkan dynamically loads all the functions it has access to depending on the system.
    self.base_wrapper = vk.BaseWrapper.load(glfw.getInstanceProcAddress);

    var required_layers: ArrayList([]const u8) = .empty;
    defer required_layers.deinit(allocator);

    if (options.enable_validation_layers) {
        try required_layers.appendSlice(allocator, validation_layers);
    }

    const layer_properties = try self.base_wrapper.enumerateInstanceLayerPropertiesAlloc(allocator);
    defer allocator.free(layer_properties);

    for (required_layers.items) |layer| {
        for (layer_properties) |l_prop| {
            const l_prop_name = std.mem.span(@as([*:0]const u8, @ptrCast(&l_prop.layer_name)));
            //std.debug.print("{s}\n", .{l_prop_name});
            if (std.mem.eql(u8, layer, l_prop_name)) {
                break;
            }
        } else {
            std.debug.print("Required layer not supported: {s}\n", .{layer});
            return error.UnsupportedLayer;
        }
    }

    const glfw_extensions = glfw.getRequiredInstanceExtensions();

    var required_extensions: ArrayList([*:0]const u8) = .empty;
    defer required_extensions.deinit(allocator);

    try required_extensions.appendSlice(allocator, glfw_extensions);
    if (options.enable_validation_layers) {
        try required_extensions.append(allocator, vk.extensions.ext_debug_utils.name);
    }

    const extension_properties = try self.base_wrapper.enumerateInstanceExtensionPropertiesAlloc(null, allocator);
    defer allocator.free(extension_properties);

    for (required_extensions.items) |extension| {
        for (extension_properties) |ext_prop| {
            if ( eq_block: {
                // since vk_prop.extension name is a 256-long char array we have to convert it to a slice.
                const vk_prop_name = std.mem.span(@as([*:0]const u8, @ptrCast(&ext_prop.extension_name)));
                const glfw_ext_name = std.mem.span(extension);
                const res = std.mem.eql(u8, vk_prop_name, glfw_ext_name);
                break :eq_block res;
            }) {
                break;
            }
        } else {
            std.debug.print("Required Extension not supported: {s}\n", .{extension});
            return error.UnsupportedExtension;
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
        .enabled_layer_count = @intCast(required_layers.items.len),
        .pp_enabled_layer_names = @ptrCast(required_layers.items),
        .enabled_extension_count = @intCast(required_extensions.items.len),
        .pp_enabled_extension_names = @ptrCast(required_extensions.items),
    };

    const instance_handle = try self.base_wrapper.createInstance(&create_info, null);
    const instance_wrapper = try allocator.create(vk.InstanceWrapper);
    errdefer allocator.destroy(instance_wrapper);
    instance_wrapper.* = vk.InstanceWrapper.load(instance_handle, self.base_wrapper.dispatch.vkGetInstanceProcAddr.?);

    self.instance = vk.InstanceProxy.init(instance_handle, instance_wrapper);
    errdefer self.instance.destroyInstance(null);
}

fn initWindow(self: *HelloTriangleApplication) !void {
    //if (c.glfwPlatformSupported(c.GLFW_PLATFORM_WAYLAND) == 1) {
    //    c.glfwInitHint(c.GLFW_PLATFORM, c.GLFW_PLATFORM_WAYLAND);
    //}
    if (c.glfwInit() != c.GLFW_TRUE) return error.GlfwInitFailed;
    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);
    self.window = c.glfwCreateWindow(width, height, "Vulkan", null, null) orelse return error.GlfwCreateWindowFailed;
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

fn setupDebugMessenger(self: *HelloTriangleApplication) !void {
    if (!options.enable_validation_layers) return;

    const severity_flags = vk.DebugUtilsMessageSeverityFlagsEXT{.warning_bit_ext = true, .error_bit_ext = true};
    const message_type_flags = vk.DebugUtilsMessageTypeFlagsEXT{.general_bit_ext = true, .performance_bit_ext = true, .validation_bit_ext = true};

    self.debug_messager = try self.instance.createDebugUtilsMessengerEXT(&.{.message_severity = severity_flags, .message_type = message_type_flags, .pfn_user_callback = debugCallback}, null);
}

fn debugCallback(
    message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
    message_types: vk.DebugUtilsMessageTypeFlagsEXT,
    p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
    p_user_data: ?*anyopaque,
) callconv(.c) vk.Bool32 {
    _ = message_severity;
    _ = p_user_data;

    const msg_type = if (message_types.general_bit_ext) "general" else if (message_types.performance_bit_ext) "performance" else if (message_types.validation_bit_ext) "validation" else "unknown";
    //const severity = if (message_severity.warning_bit_ext) "warning" else if (message_severity.error_bit_ext) "error" else "unknown";
    const callback_msg = if (p_callback_data) |callback| callback.p_message orelse "No Message." else "No Data.";

    std.debug.print("validation layer: type {s} msg: {s}\n", .{msg_type, callback_msg});
    return .false;
}
