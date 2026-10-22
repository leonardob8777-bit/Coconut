// SPDX-License-Identifier: AGPL-3.0-only
#import "AccessBridge.h"
#import <UIKit/UIKit.h>
#include <sys/sysctl.h>
#include <mach/machine.h>
#include <unistd.h>
#include "darksword.h"
#include "utils.h"
#include "offsets.h"
#include "sbx.h"

int CoconutPrepareAccess(void) {
    // Check the engine's supported OS families before offsets_init(), which
    // exits the process on unsupported versions. No call runs at app startup.
    char model[128] = {0}, build[128] = {0};
    size_t modelSize = sizeof(model), buildSize = sizeof(build);
    NSOperatingSystemVersion os = NSProcessInfo.processInfo.operatingSystemVersion;
    if (sysctlbyname("hw.machine", model, &modelSize, NULL, 0) != 0 ||
        sysctlbyname("kern.osversion", build, &buildSize, NULL, 0) != 0 ||
        model[0] == '\0' || build[0] == '\0' ||
        strncmp(model, "iPhone", 6) != 0 || strncmp(model, "iPhone18,", 9) == 0) return 1;
    bool supportedOS = os.majorVersion == 17 ||
        (os.majorVersion == 18 &&
         (os.minorVersion < 7 || (os.minorVersion == 7 && os.patchVersion <= 1))) ||
        (os.majorVersion == 26 && os.minorVersion == 0 && os.patchVersion <= 1);
    if (!supportedOS) return 1;
    struct kinfo_proc process = {0};
    int query[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    size_t size = sizeof(process);
    if (sysctl(query, 4, &process, &size, NULL, 0) != 0 || size != sizeof(process) ||
        (process.kp_proc.p_flag & P_TRACED) != 0) return 2;
    static bool attempted = false;
    @synchronized(NSProcessInfo.processInfo) {
        if (attempted) return 3;
        attempted = true;
    }
    @try {
        init_offsets();
        offsets_init();
        // Get compatibility data before entering the primitive. This probe
        // uses libgrabkernel2's device/build downloader, not vnode redirection.
        if (!emergencyfixfunctiontobereplacedlateronquestionmark() && !dlkcache()) return 4;
        if (ds_run() != 0 || !ds_is_ready() || ds_get_our_proc() == 0 ||
            ds_get_our_task() == 0 || ds_get_kernel_base() == 0) return 5;
        if (sbx_escape(ds_get_our_proc()) != 0) return 6;
        return 0;
    } @catch (NSException *exception) {
        // Do not expose memory addresses or exception internals in the report.
        return 7;
    }
}
