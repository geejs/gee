Pkg = require("../../package.json")
Fs = require("fs")
Logger = require("../lib/common/logger")
Path = require("path")
Run = require("../lib/run")
Utils = require("../lib/common/utils")
log = Logger.getLogger("pm-run")
Promise = require("bluebird")
Str = require("underscore.string")
findup = require("findup-sync")
startCwd = process.cwd()

if !process.env.NODE_ENV  or process.env.NODE_ENV == 'development'
  Promise.longStackTraces()

usage = """
Usage: pm run TASK [(options|task-options)...]

Options:
  -f, --projfile <file>     Use projfile instead of `Projfile.*`
      --log-no-indent       Disable log indenting
      --log-level           Log level (debug, info, warn, error)
      --log-plain           Disable colors
  -m, --mode <mode>         Set build mode, eg 'release'
  -s, --serve [dir]         Serves assets through HTTP/HTTPS
  -w, --watch               Watch and run tasks as needed
  -V, --version             Get version
  -?, --help                Show this usage screen

"""

usageExample = """
Examples:
  # Run task scripts with debug on to trace all filters
  pm run scripts --log-level debug

  # Run scripts task with options in release mode
  pm run scripts -m release

  # Run and watch all
  pm run scripts -w
"""

argv = require("minimist")(process.argv.slice(2), {
  alias:
    f: "projfile"
    m: "mode"
    w: "watch"
    V: "version"
    "?": "help"
    h: "help"
    usage: "usage"

  default:
    mode: ""
})


###
# Finds project file from current directory and up.
#
# @returns {*}
###
findProjfile = ->
  if argv.projfile
    filename = findup(argv.projfile)
    throw new Error("Projfile not found: #{argv.projfile}") if !filename
  else
    filename = findup("Projfile.js") || findup("Projfile.coffee")

  unless filename
    throw new Error("Projfile not found in #{process.cwd()} or any of its parent directories")

  filename


_run = (handler) ->
  Promise
    .try(findProjfile)
    .then (projfilePath) ->
      # Set current working directory to location of projfile as early as
      # possible. Gulp seems to cache process.cwd.
      process.chdir Path.dirname(projfilePath)
      projfilePath
    .then(handler)


###
# Runs this script
###
run = ->
  handler = (projfilePath) ->
    mode = if argv.mode then "mode=#{argv.mode}" else ""
    p = Path.relative(startCwd, projfilePath)
    if log.DEBUG
      console.log "gee v#{Pkg.version} projfile=#{p} #{mode}"
    Run.run argv: argv, tasks: argv._, projfilePath: projfilePath

  _run(handler)
    .catch (err) ->
      if err == "usage"
        process.exit 1
      else if err.stack
        log.error err.stack
      else if err != "PM_SILENT"
        log.error err
      process.exit 1


###
# Gets task descriptions from project file
###
taskDescriptions = ->
  handler = (projfilePath) ->
    Run.taskDescriptions {argv: argv, tasks: argv._, projfilePath: projfilePath}

  _run handler


helpCalled = false
help = ->
  # worried about circular since help calls task descriptions
  # and task descriptions can run
  return if helpCalled
  helpCalled = true

  taskDescriptions()
    .then (descriptions) ->
      tasks = []
      for name, description of descriptions
        tasks.push Str.sprintf("  %-#{24}s  #{description}", name)

      console.log usage
      if tasks.length > 0
        console.log "Tasks:"
        console.log tasks.sort().join("\n")
      else
        console.log usageExample
    .catch (err) ->
      console.error if err.stack then err.stack else err

if argv.help
  help()
else
  run()
