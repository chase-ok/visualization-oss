
byMajorCSV = '/data/college-majors/95-96/by-95-96-major12-simple.csv'

exports.loadByMajor = (done) ->
    $.ajax(byMajorCSV).done (content) -> parseByMajor content, done

parseByMajor = (content, done) ->
    byMajor = {}
    rows = d3.csv.parseRows content

    byMajor.headers = rows[0][1..]
    byMajor.totals = (+total for total in rows[1][1..])
    byMajor.fields = {}

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