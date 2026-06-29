import Foundation

/// Samples the process's physical memory footprint via mach `task_vm_info`.
///
/// `phys_footprint` is the byte count macOS Activity Monitor reports in its
/// "Memory" column — the right metric for the lean-memory requirement (M1). The
/// sampler is view-free and cheap enough to ride the DEBUG dump timer; it returns
/// `nil` only if the mach call fails.
enum MemorySampler {
    static func currentFootprintBytes() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        return info.phys_footprint
    }
}
