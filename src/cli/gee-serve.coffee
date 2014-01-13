Pkg = require("../../package.json")
Server = require("../lib/serve/server")
Fs = require("fs")
argv = require("minimist")(process.argv.slice(2), {
  h: "help",
  V: "version"
})

###
# Finds the Projfile
###
findProjfile = ->
  files = ['Projfile.js', 'Projfile.coffee']
  for file in files
    if Fs.existsSync(file)
      return file
  null


###
# Runs the server.
###
main = ->
  try
    program.dirname = program.args[0] || "."
    Server.run program
  catch ex
    console.error ex.toString()


###
# Diplays usage then exits.
###
exitUsage = ->
  console.log """
  Usage: pm serve [dirname] [options]

  Options
    -p,  --http-port <port>   HTTP port. Defaults to 1080.
    -P,  --https-port <port>  HTTPS port. Defaults to 10443.
  """
  process.exit 0

if argv.help
  exitUsage()

if argv.version
  console.log  Pkg.name + " " + Pkg.version
  process.exit 0

main()

