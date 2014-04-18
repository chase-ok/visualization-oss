{mongoose} = db = require '../../db'
Q = require 'q'
{memoizeUnary} = utils = require '../../utils'
{Smooth} = require './Smooth'

EARTH_RADIUS = 6378.1 # km

degToRad = (x) -> x*Math.PI/180
{sin, cos, atan2, sqrt, abs} = Math

# Haversize formula in km
distance = ([lat1, lon1], [lat2, lon2]) ->
    dLat = degToRad lat2 - lat1
    dLon = degToRad lon2 - lon1
    lat1 = degToRad lat1
    lat2 = degToRad lat2

    a = sin(dLat/2)**2 + (sin(dLon/2)**2)*cos(lat1)*cos(lat2)
    c = 2*atan2(sqrt(a), sqrt(1-a))
    EARTH_RADIUS*c

smoothSpeeds = (times, lats, lons) ->
    return unless times.length >= 7

    times = (t.getTime()/(60*60*1000) for t in times)
    n = times.length
    
    latSpline = Smooth lats
    lonSpline = Smooth lons

    step = (times[n-1] - times[0])/n
    samples = (times[0] + step*i for i in [0...n])

    sampledLats = []
    sampledLons = []
    dataIndex = 0
    sampleIndex = 0
    for sample, sampleIndex in samples
        while dataIndex < n-1 and times[dataIndex+1] <= sample
            dataIndex++
        p = (sample - times[dataIndex])/(times[dataIndex+1] - times[dataIndex])
        sampledLats.push latSpline dataIndex+p
        sampledLons.push lonSpline dataIndex+p

    console.log lats[0...10]
    console.log sampledLats[0...10]

    dlats = savitzkyGolayDerivativeWindow7 lats, step
    dlons = savitzkyGolayDerivativeWindow7 lons, step

    # Small distances approximation
    # http://en.wikipedia.org/wiki/Geographical_distance 
    k1 = 111.13209 - 0.56605*cos(2*lats[0]) + 0.00120*cos(4*lats[0])
    k2 = 111.41513*cos(lats[0]) - 0.09455*cos(3*lats[0]) +
         0.00012*cos(5*lats[0])

    speeds = []
    for dlat, i in dlats
        speeds.push EARTH_RADIUS*sqrt((k1*dlat)**2 + (k2*dlons[i])**2)
    speeds

_sgdw7Coeffs = (c/28 for c in [-3, -2, -1, 0, 1, 2, 3])
savitzkyGolayDerivativeWindow7 = (xs, dt) ->
    return [] unless xs?.length >= 7

    ys = []
    for i in [0...xs.length-6]
        y = 0.0
        for j in [0...7]
            if j isnt 3
                y += xs[i+j]*_sgdw7Coeffs[j]/dt
        ys.push y
        
    y0 = ys[0]
    yN = ys[ys.length-1]
    [y0, y0, y0].concat ys, [yN, yN, yN]

_sgsw7Coeffs = (c/21 for c in [-2, 3, 6, 7, 6, 3, -2])
savitzkyGolaySmoothWindow7 = (xs) ->
    return [] unless xs?.length >= 7

    ys = []
    for i in [0...xs.length-6]
        y = 0.0
        for j in [0...7]
            if j isnt 3
                y += xs[i+j]*_sgsw7Coeffs[j]
        ys.push y
        
    y0 = ys[0]
    yN = ys[ys.length-1]
    [y0, y0, y0].concat ys, [yN, yN, yN]

exports.speedSchema = speedSchema = new mongoose.Schema
    vehicleId: String
    timestamp: Date
    speed: Number
speedSchema.index 'vehicleId timestamp'

exports.getSpeedModel = memoizeUnary (prefix) ->
    mongoose.model "#{prefix}Speed", speedSchema

exports.computeSpeeds = (prefix) ->
    Speed = exports.getSpeedModel prefix
    VehicleUpdate = require('../raw/vehicleFeeds').getUpdateModel prefix

    computeForVehicle = (vehicleId) ->
        pipeline = VehicleUpdate.aggregate()
            .match {vehicleId}
            .group
                _id:
                    tripId: '$tripId'
                    day: '$start'
                times: $push: '$timestamp'
                lats: $push: '$lat'
                lons: $push: '$lon'
            .sort 'times'
            .project '-_id times lats lons'

        Q.ninvoke pipeline, 'exec'
        .then (paths) ->
            Q.all (computeForPath vehicleId, path for path in paths)

    computeForPath = (vehicleId, {times, lats, lons}) ->
        return Q() unless times?.length > 1

        speeds = []
        for i in [1...times.length]
            dt = (times[i] - times[i-1])/(60*60*1000) # hours
            continue unless dt > 1e-5
            dx = distance [lats[i-1], lons[i-1]], [lats[i], lons[i]]
            speeds.push dx/dt

        speeds = savitzkyGolaySmoothWindow7 speeds
        
        speedDocs = []
        for speed, i in speeds
            speedDocs.push
                vehicleId: vehicleId
                timestamp: times[i]
                speed: speed
        db.batchInsert Speed, speedDocs
    
    VehicleUpdate.distinctQ 'vehicleId'
    .then (vehicleIds) ->
        deferred = Q.defer()
        
        batchSize = 4
        doBatch = (index) ->
            console.log "Batch ##{index+1}"
            return deferred.resolve() if index >= vehicleIds.length
            batch = vehicleIds[index...index+batchSize]
            Q.all (computeForVehicle id for id in batch)
            .catch (error) -> deferred.reject error
            .then -> doBatch index + batchSize
        doBatch 0

        deferred.promise


exports.sequenceSpeedSchema = seqSpeedSchema = new mongoose.Schema
    tripId:
        type: String
        index: yes
    sequence:
        type: Number
        index: yes
    timestamps: [Date]
    speeds: [
        timestamp: Date
        value: Number
    ]
    speedDistribution:
        mean: Number
        median: Number
        min: Number
        max: Number
        std: Number

exports.getSequenceSpeedModel = memoizeUnary (prefix) ->
    mongoose.model "#{prefix}SequenceSpeed", seqSpeedSchema

exports.computeSequenceSpeeds = (prefix, temporary='tempseqspeed') ->
    VehicleUpdate = require('../raw/vehicleFeeds').getUpdateModel prefix
    Trip = require('../raw/trips').getModel prefix
    StopTime = require('../raw/stopTimes').getModel prefix

    findSequences = (trip) ->
        StopTime.findQ {tripId: trip.tripId}, 'sequence'
        .then (stopTimes) -> Q (t.sequence for t in stopTimes)

    compileSpeeds = (trip, sequence) ->
        gatherPaths trip, sequence
        .then (paths) ->
            console.log paths[0]


    gatherPaths = (trip, sequence) ->
        pipeline = VehicleUpdate.aggregate()
            .match {tripId: trip.tripId, stopSequence: sequence}
            .group
                _id:
                    vehicle: '$vehicleId'
                    day: '$start'
                timestamps: $push: '$timestamp'
                lats: $push: '$lat'
                lons: $push: '$lon'
        Q.ninvoke pipeline, 'exec'

    db.batchStream Trip.find({}, 'tripId'), 1, ([trip]) ->
        findSequences trip
        .then (sequences) ->
            Q.all (compileSpeeds trip, seq for seq in sequences)

    

###
exports.computeSequenceVelocities = (prefix, temporary='tempseqvel') ->
    VehicleUpdate = require('../raw/vehicleFeeds').getUpdateModel prefix
    
    pipeline = [
        {$group:
            _id:
                tripId: '$tripId'
                vehicleId: '$vehicleId'
                sequence: '$stopSequence'
                day: '$start'
            startTime: $min: '$timestamp'
            stopTime: $max: '$timestamp'
            lats: $push: '$lat'
            lons: $push: '$lon'
            times: $push: '$timestamp'
        },
        {$group:
            _id:
                tripId: '$_id.tripId'
                sequence: '$_id.sequence'
                day: '$_id.day'
            startTime: $min: '$startTime'
            stopTime: $max: '$stopTime'
            byVehicle: $push:
                lats: '$lats'
                lons: '$lons'
                times: '$times'
        },
        {$group:
            _id:
                tripId: '$_id.tripId'
                sequence: '$_id.sequence'
            byDay: $push:
                startTime: '$startTime'
                stopTime: '$stopTime'
                byVehicle: '$byVehicle'
        },
        {$out: temporary}
    ]

    pipeline = [
        {$project:
            vehicleId: '$vehicleId'
        },
        {$out: temporary}
    ]
    
    console.log pipeline

    command =
        aggregate: VehicleUpdate.name
        pipeline: pipeline
        allowDiskUse: yes
    VehicleUpdate.db.db.command command, (error, result) ->
        console.log {error, result}
###

if require.main is module
    db.connect()
    .then -> console.log 'connected'
    .then -> db.dropModel exports.getSpeedModel 'Mbta'
    .then -> exports.computeSpeeds 'Mbta'
    .catch console.error
    .done -> console.log 'done'; process.exit()
        



            



