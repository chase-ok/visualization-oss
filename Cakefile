fs = require 'fs'

{print} = require 'sys'
{spawn, exec} = require 'child_process'

execAndLog = (cmd, done) ->
  exec cmd, (err, stdout, stderr) ->
    process.stderr.write stderr if stderr?
    print stdout if stdout?
    process.stderr.write err.toString() if err
    done? err

publicJs = 'public/js'

makeBrowserifyArgs = (pack) ->
  "#{publicJs}/#{pack}/index.coffee --debug
   --transform node_modules/coffeeify
   -o #{publicJs}/#{pack}/index.js"

browserifyDirs = ['networks']

for dir in browserifyDirs
  do (dir) -> 
    task "build:#{dir}", ->
      execAndLog "browserify #{makeBrowserifyArgs dir}"
    task "watch:#{dir}", ->
      execAndLog "watchify #{makeBrowserifyArgs dir}"

# for sublime 3
task 'sbuild', ->
  for dir in browserifyDirs
    execAndLog "browserify #{makeBrowserifyArgs dir}"

task 'server', 'Starts the node server', ->
  execAndLog 'node app.js'
