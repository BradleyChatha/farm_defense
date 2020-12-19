-- Globals:
--  ConsoleLoggerStyle - Converted enum from D.
--  LogLevel - Converted enum from D.

local bit = require("bit")

local loggers = {}

local function addConsoleLogger(style, minLogLevel)
    table.insert(loggers, {
        type = "console",
        style = style,
        minLogLevel = minLogLevel
    })
end

addConsoleLogger(
    bit.bor(
        ConsoleLoggerStyle.coloured,
        ConsoleLoggerStyle.fileInfo,
        ConsoleLoggerStyle.logLevel,
        ConsoleLoggerStyle.funcInfo,
        ConsoleLoggerStyle.timestamp
    ),
    LogLevel.trace
)

-- A bit weird to be able to log here, but it's possible due to how everything's setup!
Logger.logError("Hey Mah!");

return loggers;