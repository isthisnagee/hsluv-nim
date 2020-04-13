import math

type
  Angle* = float
  Point* = object
    x*: float
    y*: float
  Line* = object
    slope*: float
    intercept*: float

proc newPoint(x: float, y: float): Point = Point(x: x, y: y)
proc newLine*(slope: float, intercept: float): Line = Line(slope: slope,
    intercept: intercept)

proc intersectLineLine*(a: Line, b: Line): Point =
  var
    x = (a.intercept - b.intercept) / (b.slope - a.slope)
    y = a.slope * x + a.intercept
  return newPoint(x, y)

proc distanceFromOrigin*(point: Point): float =
  (point.x.pow(2) + point.y.pow(2)).sqrt()

proc distanceLineFromOrigin*(line: Line): float =
  # https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
  line.intercept.abs() / (line.slope.pow(2) + 1).sqrt()

proc perpendicularThroughPoint*(line: Line, point: Point): Line =
  var
    slope = -1 / line.slope
    intercept = point.y - slope * point.x
  return newLine(slope, intercept)

proc angleFromOrigin*(point: Point): Angle =
  arctan2(point.y, point.x)

proc normalizeAngle*(angle: Angle): Angle =
  var m = 2 * PI
  return ((angle.mod(m)) + m).mod(m);
  # public static function normalizeAngle(angle:Angle):Angle {
  #     var m = 2 * Math.PI;
  #     return ((angle % m) + m) % m;
  # }

proc lengthOfRayUntilIntersect*(theta: Angle, line: Line): float =
  # theta  -- angle of ray starting at (0, 0)
  # m, b   -- slope and intercept of line
  # x1, y1 -- coordinates of intersection
  # len    -- length of ray until it intersects with line

  # b + m * x1        = y1
  # len              >= 0
  # len * cos(theta)  = x1
  # len * sin(theta)  = y1


  # b + m * (len * cos(theta)) = len * sin(theta)
  # b = len * sin(hrad) - m * len * cos(theta)
  # b = len * (sin(hrad) - m * cos(hrad))
  # len = b / (sin(hrad) - m * cos(hrad))
  return line.intercept / (theta.sin() - line.slope * theta.cos())
