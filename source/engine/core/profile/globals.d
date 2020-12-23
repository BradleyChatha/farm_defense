module engine.core.profile.globals;

// Really can't be arsed with syncing something like this between threads, so it's all thread local.
// I'll just fix up any issues with threads not dumping their data when they show up.

import std.datetime : SysTime;
import engine.core.profile;

/// Max amount of finished blocks before forcing a flush.
///
/// Profiling is strictly a development feature, so having the thread freeze for a bit during a flush isn't something
/// to care about it since it won't always be enabled.
enum PROFILE_MAX_FINISHED_BLOCKS = 10_000;

package ProfileBlock[string] g_profileActiveBlocks;
package ProfileBlock[PROFILE_MAX_FINISHED_BLOCKS] g_profileFinishedBlocks;
package size_t g_profileFinishedBlocksCount;
package string g_profileThreadName;
package __gshared SysTime g_profileInitTime; // Write-once value that is used to generated the folder name for the profiler output.