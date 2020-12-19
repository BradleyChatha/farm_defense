module engine.core.logging.sink;

// HEAVILY ASSUMES that sinks are populated *before* the logging thread is actually started up, hence the complete lack of sync code.
//
// It is safe to assume that log sinks will only be executed on the logging thread, however that still means that the actual resources
// your sink accesses will also need to be thread-safe if they're accessed across threads.
import engine.core;

alias LogSink = void delegate(LogMessage message);

package __gshared LogSink[] g_logSinks;

void addLoggingSink(LogSink sink)
{
    g_logSinks ~= sink;
}