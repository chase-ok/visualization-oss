
from numpy import *
from matplotlib.pyplot import *
import paths

SEC = 1.
METER = 1/1000.
KM = 1.
KPH = 1*KM/(60*60*SEC)

def velocities_to_speeds(velocities):
    return sqrt(sum(velocities**2, axis=1)) 

class Trip(object):

    def __init__(self, times, path, true_path=None, true_velocities=None, 
                 start_time=None):
        self.times = times
        self.path = path
        self.true_path = true_path
        self.true_velocities = true_velocities
        self.start_time = start_time

    @property
    def naive_velocities(self):
        return self.path.segments/self.durations[:, newaxis]*(60*60*SEC)

    @property
    def durations(self):
        return diff(self.times)

    def plot_naive_speeds(self, *plot_args, **plot_kwargs):
        plot(self.times[:-1], velocities_to_speeds(self.naive_velocities), 
             *plot_args, **plot_kwargs)
    
    def plot_true_speeds(self, *plot_args, **plot_kwargs):
        plot(self.times[:-1], velocities_to_speeds(self.true_velocities[:-1]), 
             *plot_args, **plot_kwargs)

    def __len__(self):
        return len(self.times)


class TripBuilder(object):

    def __init__(self):
        self.times = []
        self.points = []
        self.true_points = []
        self.true_velocities = []

    def append(self, time, point, 
               true_point, true_velocity):
        self.times.append(time)
        self.points.append(point)
        self.true_points.append(true_point)
        self.true_velocities.append(true_velocity)

    def build(self):
        return Trip(array(self.times), paths.Path(self.points), 
                    paths.Path(self.true_points), array(self.true_velocities))

def constant_speed(speed):
    return lambda t: speed

def clipped_sin_speed(max_speed, period):
    return lambda t: max(0, max_speed*sin(2*pi*t/period))

def duty_cycle_speed(speed, period, duty):
    from scipy.signal import square
    return lambda t: speed/2*(1 + square(2*pi*t/period, duty))

def no_position_error(position, velocity):
    return position

def gaussian_position_error(std):
    def transform(position, velocity):
        return position + random.normal(0, std, position.shape)
    return transform

def constant_sample_time(time):
    return lambda: time

def gaussian_sample_time(mean, std):
    return lambda: random.normal(mean, std)

def exponential_sample_time(minimum, scale):
    return lambda: minimum + random.exponential(scale)

class Vehicle(object):
    
    def __init__(self, speed_distr, position_transform=no_position_error):
        self.speed_distr = speed_distr
        self.position_transform = position_transform

    def drive_path(self, path, 
                   sample_time_dist=constant_sample_time(30*SEC),
                   dt=1*SEC):
        trip = TripBuilder()

        length = 0
        time = 0
        next_sample = -1
        last_speed = 0
        while True:
            if time > next_sample:
                true_position = path.position(length)
                velocity = last_speed*path.direction(length)
                position = self.position_transform(true_position, velocity)
                trip.append(time, position, true_position, velocity)
                next_sample = time + sample_time_dist()

            last_speed = self.speed_distr(time)
            length += last_speed*dt
            time += dt

            if length >= path.length:
                break

        return trip.build()


def path_test():
    path = paths.single_segment_path(0.6*KM)
    path += paths.corner_path(1*KM)
    path += paths.single_segment_path(0.3*KM)
    path += paths.single_segment_path(0.5*KM, pi/2)
    path += paths.single_segment_path(0.4*KM, pi/4)
    path += paths.single_segment_path(1.0*KM, -pi/2)
    path.plot('k-'); hold(True)

    bus = Vehicle(duty_cycle_speed(30*KPH, 120*SEC, 0.6), 
                  gaussian_position_error(15*METER))

    trip = bus.drive_path(path,
                          exponential_sample_time(30*SEC, 5*SEC))
    trip.path.plot('rx')

    gca().set_aspect('equal')
    show()

def speeds_test():
    path = paths.single_segment_path(0.6*KM)
    path += paths.corner_path(1.0*KM)
    path += paths.single_segment_path(0.3*KM)
    path += paths.single_segment_path(0.5*KM, pi/2)
    path += paths.single_segment_path(0.4*KM, pi/4)
    path += paths.single_segment_path(1.0*KM, -pi/2)

    bus = Vehicle(duty_cycle_speed(30*KPH, 120*SEC, 0.8), 
                  gaussian_position_error(15*METER))

    trip = bus.drive_path(path,
                          exponential_sample_time(30*SEC, 5*SEC))

    trip.plot_naive_speeds('r-', label='naive'); hold(True)
    trip.plot_true_speeds('b--', label='true')
    legend()
    show()

if __name__ == '__main__':
    path_test()
    speeds_test()
