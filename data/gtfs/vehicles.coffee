{mongoose} = db = require '../db'
utils = require './utils'
Q = require 'Q'
http = require 'q-io/http'
http2 = require 'http'


exports.schema = schema = new mongoose.Schema
    tripId: String
    start: Date
    scheduleRelationship: Number
    lat: Number
    lon: Number
    currentStopSequence: Number
    timestamp: Date


readStream = (url) ->
    http.read url
    .then (response) ->
        proto = utils.getRealtimeProto 'FeedMessage'
        parseMessage proto.decode response
    .fail (err) -> console.log err


parseMessage = (message) ->
    {header, entity} = message



if require.main is module
    readStream 'http://developer.mbta.com/lib/gtrtfs/Vehicles.pb'
    .done -> process.exit()