
import mbta_data
trips = mbta_data.create_trip_sample()
path = trips[0].true_path


import point_model
point_model.run(trips)


