const c = @import("c");
const vk = @import("vulkan");

pub fn getInstanceProcAddress(vk_instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction {
    return @ptrCast(c.glfwGetInstanceProcAddress(@ptrFromInt(@intFromEnum(vk_instance)), procname));
}

//pub fn getRequiredInstanceExtensions(count: *u32) ?[*]const [*:0]const u8 {
//    return @ptrCast(c.glfwGetRequiredInstanceExtensions(count));
//}

pub fn getRequiredInstanceExtensions() []const [*:0]const u8 {
    var ext_count: u32 = 0;
    return @ptrCast(c.glfwGetRequiredInstanceExtensions(&ext_count)[0..ext_count]);
}
