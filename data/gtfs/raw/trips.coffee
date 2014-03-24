
{mongoose} = db = require '../../db'
csv = require 'csv'
utils = require './utils'
Q = require 'Q'
{memoizeUnary} = require '../../utils'

fields =
    routeId: 'route_id'
    serviceId: 'service_id'
    tripId: 'trip_id'
    headsign: 'trip_headsign'
    direction: utils.intField 'direction_id'
    blockId: 'block_id'
    shapeId: 'shape_id'

exports.schema = schema = utils.buildCsvSchema fields
schema.index {routeId: 1}
schema.index {serviceId: 1}
schema.index {tripId: 1}, {unique: yes}
schema.index {blockId: 1}

exports.load = (prefix, baseDir) ->
    model = exports.getModel prefix
    utils.resetCsvModel model, fields, "#{baseDir}/trips.txt"

exports.getModel = memoizeUnary (prefix) -> 
    mongoose.model "#{prefix}Trip", schema

if require.main is module
    db.connect()
    .then -> exports.load 'Mbta', utils.mbtaDir
    .done -> process.exit()