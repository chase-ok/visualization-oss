

parseMapFromCSV = (csvUrl) ->
    Q $.ajax csvUrl
    .then (file) -> Q d3.csv.parseRows file
    .then (rows) -> Q new RowStack rows
    .then skipHeader
    .then parseMap

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

exports.loadGenderToFirstMajor = ->
    parseMapFromCSV '/data/college-majors/bps-2001/gender-to-first-major.csv'

byMajorCSV = '/data/college-majors/95-96/by-95-96-major12-simple.csv'

exports.loadByMajor = (done) ->
    $.ajax(byMajorCSV).done (content) -> parseByMajor content, done

parseByMajor = (content, done) ->
    byMajor = {}
    rows = d3.csv.parseRows content

    byMajor.headers = rows[0][1..]
    byMajor.totals = (+total for total in rows[1][1..])
    byMajor.fields = {}
    byMajor.total = 3306190 # from xlsx file

    i = 2
    nextRow = -> i += 1; rows[i-1]
    hasRow = -> i < rows.length

    groupName = null
    while hasRow()
        row = nextRow()

        if not row[0].trim() and hasRow()
            byMajor.fields[groupName] = group if groupName?
            groupName = nextRow()[0].trim()
            group = {}
            row = nextRow()

        group[row[0].trim()] = (+x.trim() for x in row[1..])

    done byMajor