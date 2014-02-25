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

vendorDir = 'client/js/vendor'
vendorLibs = [ # need to specify in order for deps
  'jquery', 
  'd3', 'd3-sankey'
  'q', 'underscore'
  'bootstrap', 'bootstrap-switch', 'bootstrap-slider', 'bootstrap-colorpicker'
]

bundleVendorLibs = ->
  libraries = ("#{vendorDir}/#{lib}.js" for lib in vendorLibs)
  execAndLog "uglifyjs #{libraries.join ' '}
              -c -e -m
              -o #{publicJs}/vendor.js 
              --source-map #{publicJs}/vendor.map 
              --source-map-url /javascripts/vendor.map
              --source-map-include-sources
              --screw-ie8"
task 'build:vendor', 'Bundle vendor js libraries', bundleVendorLibs

task 'server', 'Starts the node server', ->
  execAndLog 'coffee app.coffee --nodejs'
