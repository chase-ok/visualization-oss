
from numpy import *
from matplotlib.pyplot import *

DX = 0.01

def discritize_path(path):
    points = []
    for dist in linspace(0, 0.999*path.length, ceil(path.length/DX)):
        points.append(path.position(dist))
    return array(points)

def point_log_likelihood(trip, discrete_path, position_std):
    like = empty((len(trip), discrete_path.shape[0]), float)
    for i in range(len(trip)):
        dist_squared = sum((discrete_path - trip.path.points[newaxis, i])**2,
                           axis=1)
        like[i] = -0.5*dist_squared/position_std**2
        like[i] -= like[i].max()
    return like

HOUR = 60*60
MAX_VEL = 80./HOUR
MIN_VEL = 1./HOUR
DVEL = 1./HOUR
VELOCITIES = linspace(MIN_VEL, MAX_VEL, (MAX_VEL - MIN_VEL)/DVEL)

def velocity_log_likelihood(trip, discrete_path, point_like, 
                            like_cutoff=-50):
    like = empty((len(trip)-1, len(VELOCITIES)), float)

    for i, (t1, t2) in enumerate(zip(trip.times, trip.times[1:])):
        dt = t2 - t1

        for j, velocity in enumerate(VELOCITIES):
            shift = int(round(velocity*dt/DX))
            if shift == 0:
                joint = point_like[i+1] + point_like[i]
            else:
                joint = point_like[i+1, shift:] + point_like[i, :-shift]

            joint = joint[joint > like_cutoff]
            if joint.size > 0:
                like[i, j] = max(like_cutoff, logaddexp.reduce(joint))
            else:
                like[i, j] = like_cutoff
        like[i] -= like[i].max()

    return like

        
def run(trips):
    true_path = trips[0].true_path
    discrete_path = discritize_path(true_path)
    point_like = point_log_likelihood(trips[0], discrete_path, 0.05)
    velocity_like = velocity_log_likelihood(trips[0], discrete_path, point_like)
    print velocity_like
    pcolor(exp(velocity_like).T)
    show()
