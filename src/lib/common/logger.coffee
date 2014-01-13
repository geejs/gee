minilog = require('minilog')
ConsoleBackend = minilog.backends.console
LogFormatter = require("./logFormatter")
argv = require("minimist")(process.argv.slice(2))

minilog.disable()
minilog.unpipe()

logFormatter = new LogFormatter(argv["log-plain"])
minilog
  .pipe(minilog.suggest)
  .pipe(logFormatter)
  .pipe(process.stdout)

indent = !Boolean(argv['log-no-indent'])

exports.DEBUG = argv.DEBUG
if argv.DEBUG
  indent = true
  argv["log-level"] = "debug"

level = switch argv["log-level"]
  when "dbg", "debug" then "debug"
  when "wrn", "warn" then "warn"
  when "err", "error" then "error"
  else "info"


minilog.suggest.clear().allow(/.*/, level)
minilog.suggest.defaultResult = false


exports.getLogger = (name) ->
  logger = minilog(name)

  logger.indent = ->
    logFormatter.indent() if indent
  logger.unindent =  ->
    logFormatter.unindent() if indent

  logger.DEBUG = level == "debug"

  logger

