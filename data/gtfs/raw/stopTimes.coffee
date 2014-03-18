
{mongoose} = db = require '../../db'
csv = require 'csv'
utils = require './utils'
Q = require 'Q'


parseTime = (x) ->
    return null unless x
    [hour, min, second] = x.split ':'
    parseInt(hour)*60*60 + parseInt(min)*60 + parseInt(second)

fields =
    stopId: 'stop_id'
    tripId: 'trip_id'
    arrival: 
        col: 'arrival_time'
        type: Number
        parse: parseTime
    departure:
        col: 'departure_time'
        type: Number
        parse: parseTime
    sequence: utils.intField 'stop_sequence'
    headsign: 'stop_headsign'
    pickupType: utils.intField 'pickup_type'
    dropOffType: utils.intField 'drop_off_type'

exports.schema = schema = utils.buildCsvSchema fields
schema.index {tripId: 1}
schema.index {stopId: 1, tripId: 1}
schema.index {stopId: 1, arrival: 1, depature: 1}
schema.index {departure: 1}

exports.load = (prefix, baseDir) ->
    model = exports.getModel prefix
    utils.resetCsvModel model, fields, "#{baseDir}/stop_times.txt"

exports.getModel = (prefix) -> mongoose.model "#{prefix}StopTime", schema

if require.main is module
    db.connect()
    .then -> exports.load 'Mbta', utils.mbtaDir
    .done -> process.exit()