import "../hsluv.nim"

const
  W3C_CONTRAST_TEXT* = 4.5
  W3C_CONTRAST_LARGE_TEXT* = 3

proc contrastRatio*(lighterL, darkerL: float): float =
  # https://www.w3.org/TR/WCAG20-TECHS/G18.html#G18-procedure
  var
    lighterY = lToY(lighterL)
    darkerY = lToY(darkerL)
  return (lighterY + 0.05) / (darkerY + 0.05)

proc lighterMinL*(r: float): float =
  yToL((r - 1) / 20)

proc darkerMaxL*(r, lighterL: float): float =
  var
    lighterY = lToY(lighterL)
    maxY = (20 * lighterY - r + 1) / (20 * r)
  return yToL(maxY)

