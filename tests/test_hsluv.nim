import unittest
import tables
import json
import hsluv

const
  ## Epsilon used for float comparisons.
  RGB_RANGE_TOLERANCE = 1.0e-11

type
  Coord = array[3, float]
  Color = object
    lch: Coord
    luv: Coord
    rgb: Coord
    xyz: Coord
    hpluv: Coord
    hsluv: Coord
  Data = Table[string, Color]


proc `=~`(x: float, y: float): bool =
  result = abs(x - y) < RGB_RANGE_TOLERANCE

proc `=~`(x: Coord, y: Coord): bool =
  x[0] =~ y[0] and
  x[1] =~ y[1] and
  x[2] =~ y[2]

let snapshot = parseFile("tests/snapshot-rev4.json")
let data = snapshot.to(Data)

suite "HSLuv":
  test "forward functions":
    for hex, color in data.pairs:
      let testRgb = hexToRgb(hex)
      assert testRgb =~ color.rgb
      let testXyz = rgbToXyz(testRgb)
      assert testXyz =~ color.xyz
      let testLuv = xyzToLuv(testXyz)
      assert testLuv =~ color.luv
      let testLch = luvToLch(testLuv)
      assert testLch =~ color.lch
      let testHsluv = lchToHsluv(testLch)
      assert testHsluv =~ color.hsluv
      let testHpluv = lchToHpluv(testLch)
      assert testHpluv =~ color.hpluv

  test "backward functions":
    for hex, color in data.pairs:
      var testLch = hsluvToLch(color.hsluv)
      assert testLch =~ color.lch
      testLch = hpluvToLch(color.hpluv)
      assert testLch =~ color.lch
      let testLuv = lchToLuv(testLch)
      assert testLuv =~ color.luv
      let testXyz = luvToXyz(testLuv)
      assert testXyz =~ color.xyz
      let testRgb = xyzToRgb(testXyz)
      assert testRgb =~ color.rgb
      assert rgbToHex(testRgb) == hex

  test "full test":
    for hex, color in data.pairs:
      assert hsluvToHex(color.hsluv) == hex
      assert hexToHsluv(hex) =~ color.hsluv
      assert hpluvToHex(color.hpluv) == hex
      assert hexToHpluv(hex) =~ color.hpluv
