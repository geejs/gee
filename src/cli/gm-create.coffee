pkg = require("../../package.json")
Create = require("../lib/create")
Path = require("path")
argv = require("minimist")(process.argv.slice(2))

# Runs the server
#
main = ->
  url = argv._[0]
  project = argv._[1] || Path.basename(program.url)
  Create.run {project, url}


# Configure program arguments.
#
if argv.help
  console.log """
  Examples:
    Create pm-skeleton-jade from //github.com/projmate/skeleton-jade
      pm create projmate/pm-skeleton-jade

    Create my-project from //github.com/projmate/skeleton-jade
      pm create projmate/skeleton-jade my-project
  """

# Setup the arguments parser.
program
  .version(pkg.version)
  .description("Create a project from git repo skeleton")
  .usage("url [dirname]")
  .option("-s, --sub-project <dirname>", "Select sub project")
  .option("-g, --git-init", "Initialize as git repo")
  .parse(process.argv)

if program.args < 3
  program.outputHelp()
else
  main()
