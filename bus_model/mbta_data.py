
from pymongo import MongoClient
client = MongoClient()
db = client['visualization-oss']

from paths import Path, path_from_lon_lat
from trips import Trip
from numpy import *
from matplotlib.pyplot import *

route8_query = dict(routeId='08',
                    headsign='Kenmore Station via South Bay Center & Ruggles Station')

def find_trip_ids(query=route8_query):
    return list(db.mbtatrips.find(query).distinct('tripId'))

def find_shape(query=route8_query):
    id = db.mbtatrips.find(query).distinct('shapeId')[0]
    return db.mbtashapes.find_one({'shapeId': id})

def shape_to_path(shape):
    points = array([[p['lon'], p['lat']] for p in shape['points']]) 
    return path_from_lon_lat(points)

def show_path():
    path = shape_to_path(find_shape())
    path.plot()
    show()

def find_real_trips(query=route8_query, min_points=10):
    trip_ids = find_trip_ids(query)

    agg = db.mbtavehicleupdates.aggregate([
        {'$match': {'tripId': {'$in': list(trip_ids)}}},
        {'$group': {'_id': {'vehicleId': '$vehicleId', 'start': '$start'},
                    'lats': {'$push': '$lat'},
                    'lons': {'$push': '$lon'},
                    'times': {'$push': '$timestamp'}}}])
    
    trips = []
    for trip in agg['result']:
        times = trip['times']
        if len(times) < min_points: continue

        path = path_from_lon_lat(array(zip(trip['lons'], trip['lats'])))
        times = [(t - times[0]).total_seconds() for t in times]

        trips.append(Trip(array(times), path))

    return trips

def create_trip_sample(query=route8_query):
    true_path = shape_to_path(find_shape(query))

    trips = find_real_trips(query)
    for trip in trips:
        trip.true_path = true_path

    return trips

sample = create_trip_sample()
sample[0].plot_naive_speeds()
show()
