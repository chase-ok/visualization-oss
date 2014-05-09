
from numpy import *
from matplotlib.pyplot import *

DX = 0.01

def discretize_path(path):
    points = []
    for dist in linspace(0, 0.999*path.length, ceil(path.length/DX)):
        points.append(path.position(dist))
    return array(points)

GPS_STD = 0.05

def point_log_likelihood(trip, discrete_path):
    like = empty((len(trip), discrete_path.shape[0]), float)
    for i in range(len(trip)):
        dist_squared = sum((discrete_path - trip.path.points[newaxis, i])**2,
                           axis=1)
        like[i] = -0.5*dist_squared/GPS_STD**2
        like[i] -= like[i].max()
    return like

HOUR = 60.*60
MAX_VEL = 80./HOUR
DVEL = 1./HOUR
VELOCITIES = linspace(0, MAX_VEL, MAX_VEL/DVEL)

def velocity_log_likelihood(trip, discrete_path, point_like, 
                            like_cutoff=-100):
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


def velocity_log_pdf(slow_mean=0/HOUR, slow_std=15/HOUR,
                 fast_mean=30/HOUR, fast_std=10/HOUR,
                 ratio=0.6, uniform=0.05):
    x = VELOCITIES
    slow = ratio*exp(-(x-slow_mean)**2/(2*slow_std**2))
    fast = (1-ratio)*exp(-(x-fast_mean)**2/(2*fast_std**2))
    mixture = slow + fast + uniform
    return log(mixture/mixture.sum())

def match_velocity_pdf(log_pdf, velocity_like):
    log_prob = 0.0
    for i in range(velocity_like.shape[0]):
        joint = log_pdf + velocity_like[i, :]
        log_prob += logaddexp.reduce(joint)
    return log_prob

def show_velocity_like(trips):
    true_path = trips[0].true_path
    discrete_path = discretize_path(true_path)
    point_like = point_log_likelihood(trips[0], discrete_path)
    velocity_like = velocity_log_likelihood(trips[0], discrete_path, point_like)
    print velocity_like
    pcolor(exp(velocity_like).T)
    show()


def bayes_update(priors, velocity_log_pdfs, trips):
    for i, trip in enumerate(trips):
        print 'trip {0} of {1}'.format(i, len(trips))

        discrete = discretize_path(trip.true_path)
        point_like = point_log_likelihood(trip, discrete)
        velocity_like = velocity_log_likelihood(trip, discrete, point_like)

        for i, log_pdf in enumerate(velocity_log_pdfs):
            priors.flat[i] += match_velocity_pdf(log_pdf, velocity_like)
        priors -= priors.max()

    return priors
            
def create_suite(*param_ranges):
    shape = tuple(len(values) for _, values in param_ranges)
    priors = zeros(shape, float)

    models = []
    for indices in ndindex(*shape):
        model_param_values = dict()
        for (param, values), index in zip(param_ranges, indices):
            model_param_values[param] = values[index]
        models.append(velocity_log_pdf(**model_param_values))

    return param_ranges, priors, models

def run(trips):
    #pdf = velocity_pdf()
    #plot(VELOCITIES, pdf(VELOCITIES))
    #show()

    plot(VELOCITIES, velocity_log_pdf(fast_mean=80/HOUR, ratio=0.01))
    show()

    param_ranges, priors, models = create_suite(
            ('fast_mean', linspace(10/HOUR, 80/HOUR)),
            ('ratio', linspace(0.05, 0.6)))

    bayes_update(priors, models, trips[:20])
    
    posteriors = exp(priors)
    posteriors /= posteriors.sum()
    #posteriors = priors

    fast_mean, ratio = meshgrid(param_ranges[0][1], param_ranges[1][1])
    pcolor(fast_mean*HOUR, ratio, posteriors)

    colorbar()
    xlabel('Speed [kph]')
    ylabel('Ratio of Slow to Fast Traffic')
    xlim([10, 80])
    ylim([0.05, 0.6])
    show()
