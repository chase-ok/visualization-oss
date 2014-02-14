
collegeData = require './college-data.coffee'
sankey = require './sankey.coffee'


collegeData.loadGenderToFirstMajor()
.then (map) -> console.log map
.done()

###
collegeData.loadByMajor (data) ->
    console.log data
    sankey.create data
###