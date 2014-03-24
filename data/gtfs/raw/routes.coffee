
{mongoose} = db = require '../../db'
csv = require 'csv'
utils = require './utils'
{memoizeUnary} = require '../../utils'
Q = require 'Q'

fields =
    routeId: 'route_id'
    agencyId: 'agency_id'
    shortName: 'route_short_name'
    longName: 'route_long_name'
    description: 'route_desc'
    routeType: utils.intField 'route_type'
    url: 'route_url'
    color: utils.colorField 'route_color'
    textColor: utils.colorField 'route_text_color'

exports.schema = schema = utils.buildCsvSchema fields
schema.index {routeId: 1}, {unique: yes}

exports.load = (prefix, baseDir) ->
    model = exports.getModel prefix
    utils.resetCsvModel model, fields, "#{baseDir}/routes.txt"

exports.getModel = memoizeUnary (prefix) -> 
    mongoose.model "#{prefix}Route", schema

if require.main is module
    db.connect()
    .then -> exports.load 'Mbta', utils.mbtaDir
    .done -> process.exit()