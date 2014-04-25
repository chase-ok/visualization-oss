
from numpy import *
from bisect import bisect_right
from matplotlib.pyplot import *

def distance(point1, point2):
    return sqrt(sum((point2 - point1)**2))

class Path(object):

    def __init__(self, points):
        self.points = array(points, dtype=float)
        self._compute_segments()
   
    @property
    def start(self): return self.points[0]

    @property
    def end(self): return self.points[-1]
    
    def _compute_segments(self):
        self.segments = diff(self.points, axis=0)
        self.segment_lengths = sqrt(sum(self.segments**2, axis=1))
        self.cum_segment_lengths = cumsum(self.segment_lengths)
        self.length = sum(self.segment_lengths)

    def _length_to_index(self, length):
        index = bisect_right(self.cum_segment_lengths, length)
        if index < 0 or index > len(self.cum_segment_lengths):
            raise ValueError(length)
        return index

    def position(self, length):
        index = self._length_to_index(length)
        if index > 0:
            length  -= self.cum_segment_lengths[index-1]
        p = float(length)/self.segment_lengths[index]
        return self.points[index] + p*self.segments[index]

    def direction(self, length):
        segment = self.segments[self._length_to_index(length)]
        return segment/linalg.norm(segment)

    def __add__(self, other_path):
        other_points = other_path.points
        if (self.points[-1] == other_path.points[0]).all():
            other_points = other_points[1:, :]
        else:
            offset = other_path.start - self.end
            other_points -= offset
        return Path(vstack((self.points, other_points))) 

    def plot(self, *plot_args, **plot_kwargs):
        plot(self.points[:, 0], self.points[:, 1], *plot_args, **plot_kwargs)

def single_segment_path(length, angle=0):
    return Path([[0, 0], [length*cos(angle), length*sin(angle)]])

def corner_path(length):
    return Path([[0, 0], [length/2., 0], [length/2., length/2.]])

if __name__ == '__main__':
    path = single_segment_path(10)
    path += corner_path(10) 
    print path.points
    print path.length
    print path.segments
    print path.position(1), path.position(16)
    print path.direction(1), path.direction(16)
    
    path.plot()
    show()
