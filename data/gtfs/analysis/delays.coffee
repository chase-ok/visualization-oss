
{mongoose} = db = require '../../db'
stops = require '../raw/stops'
stopTimes = require '../raw/stopTimes'
trips = require '../raw/trips'
tripFeeds = require '../raw/tripFeeds'
utils = require './utils'

exports.analyze = (prefix) ->
    schema = new mongoose.Schema
        stop: utils.makeRef "#{prefix}Stop"
        trip: utils.makeRef "#{prefix}Trip"
        route: utils.makeRef "#{prefix}Route"
        sequence: Number
        scheduledTime: Number
        delays: [Number]
    model = mongoose.model "#{prefix}Delay", schema
    
    createEmpties = ->
    
    db.dropModel model
    .then createEmpties


