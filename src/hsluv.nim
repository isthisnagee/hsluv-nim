# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.
import math
import sequtils
import strutils
import "hsluv/geometry.nim"

type
  ## An alias for an array of 3 floats.
  Coord* = array[3, float]

const
  m = [
        [3.240969941904521, -1.537383177570093, -0.498610760293],
        [-0.96924363628087, 1.87596750150772, 0.041555057407175],
        [0.055630079696993, -0.20397695888897, 1.056971514242878],
    ]
  minv =
    [
        [0.41239079926595, 0.35758433938387, 0.18048078840183],
        [0.21263900587151, 0.71516867876775, 0.072192315360733],
        [0.019330818715591, 0.11919477979462, 0.95053215224966]
    ]
  refY = 1.0
  refU = 0.19783000664283
  refV = 0.46831999493879
  # CIE LUV constants
  kappa = 903.2962962
  epsilon = 0.0088564516
  hexChars = "0123456789abcdef";

proc dotProduct[I](A: array[I, float], B: array[I, float]): float =
  result = 0
  for (a, b) in zip(A, B):
    result += a * b

proc fromLinear(c: float): float =
  if c <= 0.0031308:
    return 12.92 * c;
  return 1.055 * c.pow(1/2.4) - 0.055;

proc toLinear(c: float): float =
  if c > 0.04045:
    return ((c + 0.055) / (1 + 0.055)).pow(2.4)
  return c / 12.92;

proc getBounds*(L: float): seq[Line] =
  ## For a given lightness, return a list of 6 lines in slope-intercept
  ## form that represent the bounds in CIELUV, stepping over which will
  ## push a value out of the RGB gamut
  result = newSeq[Line]()
  var
    sub1 = (L + 16).pow(3) / 1560896
    sub2 = if sub1 > epsilon: sub1 else: L / kappa
  for c in 0..<3:
    var
      m1 = m[c][0]
      m2 = m[c][1]
      m3 = m[c][2]
    for t in 0..<2:
      var
        tf = t.toFloat
        top1 = (284517 * m1 - 94839 * m3) * sub2
        top2 = (838422 * m3 + 769860 * m2 + 731718 * m1) * L * sub2 - 769860 *
            tf * L
        bottom = (632260 * m3 - 126452 * m2) * sub2 + 126452.0 * tf
      result.add(newLine(top1 / bottom, top2 / bottom))

proc maxSafeChromaForL*(L: float): float =
  ## For given lightness, returns the maximum chroma. Keeping the chroma value
  ## below this number will ensure that for any hue, the color is within the RGB
  ## gamut.
  result = Inf
  var bounds = getBounds(L)
  for bound in bounds:
    result = min(distanceLineFromOrigin(bound), result)

proc maxChromaForLH*(L, H: float): float =
  var
    hrad = H / 360.0 * PI * 2.0
    bounds = getBounds(L)
  result = Inf
  for bound in bounds:
    var length = lengthOfRayUntilIntersect(hrad, bound)
    if length >= 0:
      result = min(result, length)

proc xyzToRgb*(xyz: Coord): Coord =
  ## XYZ coordinates are ranging in [0;1] and RGB coordinates in [0;1] range.
  ## @param xyz An array containing the color's X,Y and Z values.
  ## @return An array containing the resulting color's red, green and blue.
  [
    fromLinear(dotProduct(m[0], xyz)),
    fromLinear(dotProduct(m[1], xyz)),
    fromLinear(dotProduct(m[2], xyz)),
  ]


proc rgbToXyz*(rgb: Coord): Coord =
  ## RGB coordinates are ranging in [0;1] and XYZ coordinates in [0;1].
  ## @param rgb An array containing the color's R,G,B values.
  ## @return An array containing the resulting color's XYZ coordinates.
  var rgbl = [
    toLinear(rgb[0]),
    toLinear(rgb[1]),
    toLinear(rgb[2]),
  ]
  return [
    dotProduct(minv[0], rgbl),
    dotProduct(minv[1], rgbl),
    dotProduct(minv[2], rgbl),
  ]

proc yToL*(Y: float): float =
  ## http://en.wikipedia.org/wiki/CIELUV
  ## In these formulas, Yn refers to the reference white point. We are using
  ## illuminant D65, so Yn (see refY in Maxima file) equals 1. The formula is
  ## simplified accordingly.
  if Y <= epsilon:
    return (Y / refY) * kappa
  else:
    return 116.0 * (Y / refY).pow(1.0 / 3.0) - 16.0

proc lToY*(L:float):float =
  if L <= 8:
    return refY * L / kappa
  else:
    return refY * ((L + 16) / 116).pow(3)

proc xyzToLuv*(xyz: Coord): Coord =
  ## XYZ coordinates are ranging in [0;1].
  ## @param tuple An array containing the color's X,Y,Z values.
  ## @return An array containing the resulting color's LUV coordinates.
  var
    X = xyz[0]
    Y = xyz[1]
    Z = xyz[2]
    # This divider fix avoids dividing by 0
    divider = (X + (15 * Y) + (3 * Z))
    varU = 4 * X
    varV = 9 * Y

  if divider != 0:
      varU /= divider
      varV /= divider
  else:
      varU = NaN;
      varV = NaN;

  var L = yToL(Y);

  if (L == 0):
    return [0.0, 0.0, 0.0];

  var 
    U = 13 * L * (varU - refU)
    V = 13 * L * (varV - refV)

  return [L, U, V];

proc luvToXyz*(luv: Coord): Coord =
  ## XYZ coordinates are ranging in [0;1].
  ## @param lvv An array containing the color's L,U,V values.
  ## @return An array containing the resulting color's XYZ coordinates.
  var 
    L = luv[0]
    U = luv[1]
    V = luv[2]

  if (L == 0):
    return [0.0, 0.0, 0.0]

  var
    varU = U / (13 * L) + refU
    varV = V / (13 * L) + refV
    Y = lToY(L)
    X = 0 - (9 * Y * varU) / ((varU - 4) * varV - varU * varV)
    Z = (9 * Y - (15 * varV * Y) - (varV * X)) / (3 * varV)

  return [X, Y, Z]

proc luvToLch*(luv: Coord): Coord =
  ## @param luv An array containing the color's L,U,V values.
  ## @return An array containing the resulting color's LCH coordinates.
  var 
    L = luv[0]
    U = luv[1]
    V = luv[2]
    C = (U * U + V * V).sqrt
    H: float

  # Greys: disambiguate hue
  if C < 0.00000001:
    H = 0
  else:
    var Hrad = arctan2(V, U)
    H = (Hrad * 180.0) / PI
    if H < 0:
      H = 360 + H

  return [L, C, H]

proc lchToLuv*(lch: Coord): Coord =
  ## @param lch An array containing the color's L,C,H values.
  ## @return An array containing the resulting color's LUV coordinates.
  var
    L = lch[0]
    C = lch[1]
    H = lch[2]
    Hrad = H / 360.0 * 2 * PI
    U = Hrad.cos() * C
    V = Hrad.sin() * C

  return [L, U, V]

proc hsluvToLch*(hsluv: Coord): Coord =
  ## HSLuv values are ranging in [0;360], [0;100] and [0;100].
  ## @param hsluv An array containing the color's H,S,L values in HSLuv color space.
  ## @return An array containing the resulting color's LCH coordinates.
  var
    H = hsluv[0]
    S = hsluv[1]
    L = hsluv[2]

  # White and black: disambiguate chroma
  if L > 99.9999999:
    return [100.0, 0.0, H]

  if L < 0.00000001:
    return [0.0, 0.0, H]

  var
    maxChroma = maxChromaForLH(L, H)
    C = maxChroma / 100 * S

  return [L, C, H]

proc lchToHsluv*(lch: Coord): Coord =
  ## HSLuv values are ranging in [0;360], [0;100] and [0;100].
  ## `lch` - An array containing the color's LCH values.
  ## @return An array containing the resulting color's HSL coordinates in HSLuv color space.
  var
    L = lch[0]
    C = lch[1]
    H = lch[2]

  # White and black: disambiguate chroma
  if L > 99.9999999:
    return [H, 0, 100]


  if L < 0.00000001:
    return [H, 0, 0];


  var
    maxChroma = maxChromaForLH(L, H)
    S = C / maxChroma * 100

  return [H, S, L]

proc hpluvToLch*(hpluv: Coord): Coord =
  ## HSLuv values are in [0;360], [0;100] and [0;100].
  ## @param hpluv An array containing the color's H,S,L values in HPLuv (pastel variant) color space.
  ## @return An array containing the resulting color's LCH coordinates.
  var
    H = hpluv[0]
    S = hpluv[1]
    L = hpluv[2]

  if L > 99.9999999:
    return [100.0, 0.0, H]


  if L < 0.00000001:
    return [0.0, 0.0, H]


  var 
    maxSafeChroma = maxSafeChromaForL(L)
    C = maxSafeChroma / 100 * S

  return [L, C, H]

proc lchToHpluv*(lch: Coord): Coord =
  ## HSLuv values are ranging in [0;360], [0;100] and [0;100].
  ## @param tuple An array containing the color's LCH values.
  ## @return An array containing the resulting color's HSL coordinates in HPLuv (pastel variant) color space.
  var
    L = lch[0]
    C = lch[1]
    H = lch[2]

  # White and black: disambiguate saturation
  if L > 99.9999999:
    return [H, 0.0, 100.0]


  if L < 0.00000001:
    return [H, 0.0, 0.0]


  var 
    maxSafeChroma = maxSafeChromaForL(L)
    S = C / maxSafeChroma * 100

  return [H, S, L]

proc rgbToHex*(rgb: Coord): string =
  ## RGB values are ranging in [0;1].
  ## @param rgb An array containing the color's RGB values.
  ## @return A string containing a `#RRGGBB` representation of given color.
  result = "#"

  for i in 0..<3:
    var 
      chan = rgb[i]
      c = (chan * 255).round()
      digit2 = c.mod(16)
      digit1 = ((c - digit2) / 16).toInt
    result.add(hexChars[digit1])
    result.add(hexChars[digit2.toInt])

proc hexToRgb*(hex: string): Coord =
  var h = hex.toLower()
  result = [0.0, 0.0, 0.0]
  for i in 0..<3:
    var
      digit1 = hexChars.find(h[i * 2 + 1])
      digit2 = hexChars.find(h[i * 2 + 2])
      n = digit1 * 16 + digit2
    result[i] = n.toFloat / 255.0

proc lchToRgb*(tup: Coord): Coord =
  ## RGB values are ranging in [0;1].
  ## @param tup An array containing the color's LCH values.
  ## @return An array containing the resulting color's RGB coordinates.
  xyzToRgb(luvToXyz(lchToLuv(tup)))

proc rgbToLch*(tup: Coord): Coord =
  ## RGB values are ranging in [0;1].
  ## @param tup An array containing the color's RGB values.
  ## @return An array containing the resulting color's LCH coordinates.
  luvToLch(xyzToLuv(rgbToXyz(tup)))

proc hsluvToRgb*(tup :Coord): Coord =
  ## HSLuv values are ranging in [0;360], [0;100] and [0;100] and RGB in [0;1].
  ## @param tup An array containing the color's HSL values in HSLuv color space.
  ## @return An array containing the resulting color's RGB coordinates.
  lchToRgb(hsluvToLch(tup))

proc rgbToHsluv*(tup :Coord): Coord =
  ## HSLuv values are ranging in [0;360], [0;100] and [0;100] and RGB in [0;1].
  ## @param tup An array containing the color's RGB coordinates.
  ## @return An array containing the resulting color's HSL coordinates in HSLuv color space.
  lchToHsluv(rgbToLch(tup))

proc hpluvToRgb*(tup:Coord): Coord =
  ## HSLuv values are ranging in [0;360], [0;100] and [0;100] and RGB in [0;1].
  ## @param tup An array containing the color's HSL values in HPLuv (pastel variant) color space.
  ## @return An array containing the resulting color's RGB coordinates.
  lchToRgb(hpluvToLch(tup))

proc rgbToHpluv*(tup :Coord): Coord =
  ## HSLuv values are ranging in [0;360], [0;100] and [0;100] and RGB in [0;1].
  ## @param tup An array containing the color's RGB coordinates.
  ## @return An array containing the resulting color's HSL coordinates in HPLuv (pastel variant) color space.
  lchToHpluv(rgbToLch(tup))

proc hsluvToHex*(tup :Coord): string =
  ## HSLuv values are ranging in [0;360], [0;100] and [0;100] and RGB in [0;1].
  ## @param tup An array containing the color's HSL values in HSLuv color space.
  ## @return A string containing a `#RRGGBB` representation of given color.
  rgbToHex(hsluvToRgb(tup))

proc hpluvToHex*(tup: Coord): string =
  rgbToHex(hpluvToRgb(tup))


proc hexToHsluv*(s: string): Coord =
  ## HSLuv values are ranging in [0;360], [0;100] and [0;100] and RGB in [0;1].
  ## @param tup An array containing the color's HSL values in HPLuv (pastel variant) color space.
  ## @return An array containing the color's HSL values in HSLuv color space.
  rgbToHsluv(hexToRgb(s))

proc hexToHpluv*(s: string): Coord =
  ## HSLuv values are ranging in [0;360], [0;100] and [0;100] and RGB in [0;1].
  ## @param hex A `#RRGGBB` representation of a color.
  ## @return An array containing the color's HSL values in HPLuv (pastel variant) color space.
  rgbToHpluv(hexToRgb(s))
