
{mongoose} = db = require '../db'
csv = require 'csv'
utils = require './utils'
Q = require 'Q'

parseDate = (x, hour, minute, second) ->
    return null unless x
    new Date(x[...4], x[4...6], x[6...8], hour, minute, second)

fields =
    serviceId: 'service_id'
    monday: utils.intField 'monday'
    tuesday: utils.intField 'tuesday'
    wednesday: utils.intField 'wednesday'
    thursday: utils.intField 'thursday'
    friday: utils.intField 'friday'
    saturday: utils.intField 'saturday'
    sunday: utils.intField 'sunday'
    start:
        col: 'start_date'
        type: Date
        parse: (x) -> parseDate x, 0, 0, 0
    end:
        col: 'end_date'
        type: Date
        parse: (x) -> parseDate x, 23, 59, 59

exports.schema = schema = utils.buildCsvSchema fields
schema.index {serviceId: 1, start:1, stop: 1}
schema.index {start: 1, stop: 1}

exports.load = (prefix, baseDir) ->
    model = mongoose.model "#{prefix}Calendar", schema
    utils.resetCsvModel model, fields, "#{baseDir}/calendar.txt"

if require.main is module
    db.connect()
    .then -> exports.load 'Mbta', utils.mbtaDir
    .done -> process.exit()