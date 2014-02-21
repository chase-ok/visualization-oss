
collegeData = require './college-data.coffee'
sankey = require './sankey.coffee'

$ ->
    Q.all [collegeData.loadGenderToFirstMajor(),
           collegeData.loadFirstMajorToThirdMajor(),
           collegeData.loadThirdMajorToFinalMajor()]
    .spread (genderToFirst, firstToThird, thirdToFinal) ->
        sankey.create {genderToFirst, firstToThird, thirdToFinal}
    .done()