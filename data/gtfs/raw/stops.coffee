
{mongoose} = db = require '../../db'
csv = require 'csv'
utils = require './utils'
Q = require 'Q'

fields =
    stopId: 'stop_id'
    code: 'stop_code'
    name: 'stop_name'
    description: 'stop_desc'
    lat: utils.floatField 'stop_lat'
    lon: utils.floatField 'stop_lon'
    zoneId: 'zone_id'
    url: 'stop_url'
    locationType: utils.intField 'location_type'
    parentStation: utils.intField 'parent_station'

exports.schema = schema = utils.buildCsvSchema fields
schema.index {stopId: 1} #, {unique: yes} --- parent stations

exports.load = (prefix, baseDir) ->
    model = exports.getModel prefix
    utils.resetCsvModel model, fields, "#{baseDir}/stops.txt"

exports.getModel = (prefix) -> mongoose.model "#{prefix}Stop", schema

if require.main is module
    db.connect()
    .then -> exports.load 'Mbta', utils.mbtaDir
    .done -> process.exit()