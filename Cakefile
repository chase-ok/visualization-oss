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

task 'build:networks', ->
  execAndLog "browserify #{makeBrowserifyArgs 'networks'}"

task 'watch:networks', ->
  execAndLog "watchify #{makeBrowserifyArgs 'networks'}"

task 'server', 'Starts the node server', ->
  execAndLog 'node app.js'
