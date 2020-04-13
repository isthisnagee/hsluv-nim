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
      let
        rgb = hexToRgb(hex)
        xyz = rgbToXyz(rgb)
        luv = xyzToLuv(xyz)
        lch = luvToLch(luv)
        hsluv = lchToHsluv(lch)
        hpluv = lchToHpluv(lch)
      assert rgb =~ color.rgb
      assert xyz =~ color.xyz
      assert luv =~ color.luv
      assert lch =~ color.lch
      assert hsluv =~ color.hsluv
      assert hpluv =~ color.hpluv

  test "backward functions":
    for hex, color in data.pairs:
      let
        lch = hsluvToLch(color.hsluv)
        luv = lchToLuv(lch)
        xyz = luvToXyz(luv)
        rgb = xyzToRgb(xyz)
      assert lch =~ color.lch
      assert luv =~ color.luv
      assert xyz =~ color.xyz
      assert rgb =~ color.rgb
      assert hpluvToLch(color.hpluv) =~ color.lch
      assert rgbToHex(rgb) == hex

  test "full test":
    for hex, color in data.pairs:
      assert hsluvToHex(color.hsluv) == hex
      assert hexToHsluv(hex) =~ color.hsluv
      assert hpluvToHex(color.hpluv) == hex
      assert hexToHpluv(hex) =~ color.hpluv
