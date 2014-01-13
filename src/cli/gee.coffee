Fs = require("fs")
Path = require("path")
Pkg = require("../../package.json")
Cp = require("child_process")
cwd = process.cwd()

argv = require("minimist")(process.argv.slice(2), {
  alias: {
    h: "help",
    V: "version"
  }
})


###
# Exceptions handler
###
process.on "uncaughtException", (err) ->
  message = err
  message = err.stack if (err.stack)
  console.error "Uncaught exception", message


###
# Exits with usage screen
###
exitUsage = ->
  usage = """
    Usage: gee COMMAND

    Commands
      create  Creates a project from git repo
      run     Runs one or more tasks in Projfile
      serve   Serves pages from directory HTTP/HTTPS
  """
  console.log usage
  process.exit 0


###
# Spawns an app, with special handling for JavaScript and CoffeeScript files.
###
spawn = (cmd, args) ->
  filename = Path.join(__dirname, "#{cmd}.js")
  if Fs.existsSync(filename)
    args.unshift filename
    cmd = "node"
  else
    filename = Path.join(__dirname, "#{cmd}.coffee")
    if Fs.existsSync(filename)
      args.unshift filename
      cmd = "coffee"

  proc = Cp.spawn cmd, args, stdio: "inherit"
  proc.on "exit", (code) ->
    if code == 127
      console.error "\n  %s(1) does not exist\n", cmd
    process.exit code


###
# Entry point into app.
###
main = ->
  command = argv._[0]
  if argv.help and !command
    exitUsage()

  if argv.version
    console.log Pkg.name + " v" + Pkg.version
    return

  if "run serve".indexOf(command) > -1
    args = process.argv.slice(3)
    spawn "gee-#{command}", args
  else if "create".indexOf(command) > -1
    console.log "#{command} has not been refactored yet :("
  else
    exitUsage()
main()
