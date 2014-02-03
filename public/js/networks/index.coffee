
collegeData = require './college-data.coffee'
sankey = require './sankey.coffee'

collegeData.loadByMajor (data) ->
    console.log data
    sankey.create data