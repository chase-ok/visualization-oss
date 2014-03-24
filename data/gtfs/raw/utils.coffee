
_ = require 'underscore'
{mongoose} = db = require '../../db'
csv = require 'csv'
Q = require 'q'
fs = require 'fs'
ProtoBuf = require 'protobufjs'

exports.gtfsDir = "#{__dirname}/../../../public/data/gtfs"
exports.mbtaDir = "#{exports.gtfsDir}/mbta"

realtime = null
exports.getRealtimeProto = (proto) ->
    if not realtime?
        file = "#{exports.gtfsDir}/gtfs-realtime.proto"
        realtime = ProtoBuf.loadProtoFile(file).build 'transit_realtime'
    return realtime[proto]

exports.parseDateString = (str, hour=0, minute=0, second=0) ->
    return null unless str
    new Date str[...4], str[4...6]-1, str[6...8], hour, minute, second

exports.numOrDefault = numOrDefault = (x, def=null) ->
    if _.isNaN x then def else x

exports.intField = (col, def=null) ->
    col: col
    type: Number
    parse: (x) -> numOrDefault parseInt(x), def

exports.colorField = (col, def=null) ->
    col: col
    type: Number
    parse: (x) -> numOrDefault parseInt(x, 16), def

exports.floatField = (col, def=null) ->
    col: col
    type: Number
    parse: (x) -> numOrDefault parseFloat(x), def

exports.buildCsvSchema = (fields) ->
    schema = {}
    for field, value of fields
        type = if _.isString value then String else value.type
        schema[field] = type
    new mongoose.Schema schema

exports.parseCsvFile = (file, fields, model) ->
    parseRow = makeParseRow fields
    deferred = Q.defer()

    csv().from.stream(fs.createReadStream(file), {columns: yes})
    .transform parseRow
    .on 'error', (err) -> deferred.reject err
    .to.array (rows) -> 
        db.batchInsert model, rows
        .then -> deferred.resolve()

    deferred.promise

makeParseRow = (fields) ->
    parsers = {}
    for field, value of fields
        parsers[field] =
            if _.isString value then {parse: ((x) -> x), col: value}
            else value

    (row) ->
        doc = {}
        for field, {col, parse} of parsers
            doc[field] = parse row[col]
        doc

exports.resetCsvModel = (model, fields, file) ->
    db.dropModel model
    .then -> exports.parseCsvFile file, fields, model
    .then -> Q model