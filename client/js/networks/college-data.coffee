
bps2001 = '/data/college-majors/bps-2001'

exports.loadGenderToFirstMajor = ->
    parseMapFromCSV "#{bps2001}/gender-to-first-major.csv"

exports.loadFirstMajorToThirdMajor = ->
    parseMapFromCSV "#{bps2001}/first-major-to-third-major.csv"

exports.loadThirdMajorToFinalMajor = ->
    parseMapFromCSV "#{bps2001}/third-major-to-final-major.csv"


parseMapFromCSV = (csvUrl) ->
    Q $.ajax csvUrl
    .then (file) -> Q d3.csv.parseRows file
    .then (rows) -> Q new RowStack rows
    .then (rows) -> Q skipHeader rows
    .then (rows) -> Q parseMap rows

class RowStack
    constructor: (@rows) -> @index = 0
    peek: -> col.trim() for col in @rows[@index]
    skip: (n=1) -> @index += n; this
    pop: -> col.trim() for col in @rows[@index++]
    isEmpty: -> @index >= @rows.length

skipText = (rows, col=0) -> rows.pop() while rows.peek()[col]; return
skipEmpty = (rows, col=0) -> rows.pop() while not rows.peek()[col]; return

skipHeader = (rows) ->
    skipText rows # header
    skipEmpty rows, 1
    Q rows

parseMap = (rows) ->
    map = {from: {}, to: {}, values: {}}

    map.from.name = rows.pop()[1]
    map.from.categories = rows.pop()[1...-1]
    map.to.name = rows.skip(5).pop()[0]
    map.to.categories = []
    map.to.sizes = {}

    while rows.peek()[0]
        [category, values...] = rows.pop()
        map.to.categories.push category
        map.values[category] = localMap = {}
        for value, i in values when value
            localMap[map.from.categories[i]] = +value/100

    skipEmpty rows 
    skipText rows # error header
    skipEmpty rows 
    skipText rows # error values
    skipEmpty rows
    skipText rows # total sample size
    skipEmpty rows

    rows.skip() # name row
    while rows.peek()[0]
        [category, size] = rows.pop()
        map.to.sizes[category] = +size

    Q map
