-- Globals:
--  LogMessageStyle - Converted enum from D.
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

local function addFileLogger(file, style, minLogLevel)
    table.insert(loggers, {
        type = "file",
        file = file,
        style = style,
        minLogLevel = minLogLevel
    })
end

local LOG_STYLE_ALL = bit.bor(
    LogMessageStyle.coloured,
    LogMessageStyle.fileInfo,
    LogMessageStyle.logLevel,
    LogMessageStyle.funcInfo,
    LogMessageStyle.timestamp
)

addConsoleLogger(LOG_STYLE_ALL, LogLevel.trace)
addFileLogger("./logs/all.log", LOG_STYLE_ALL, LogLevel.trace)
addFileLogger("./logs/warn_and_error.log", LOG_STYLE_ALL, LogLevel.warning)

-- A bit weird to be able to log here, but it's possible due to how everything's setup!
Logger.logError("Hey Mah!");

return loggers;