# img2ppm.nim
# Use stb_image via a C wrapper

{.compile: "stb_image_wrapper.c".}

# Bindings
proc stbi_load(filename: cstring, x, y, channels_in_file: ptr cint, desired_channels: cint): ptr uint8
  {.importc, cdecl.}
proc stbi_image_free(retval_from_stbi_load: pointer)
  {.importc, cdecl.}

proc savePPM(filename: string, data: ptr uint8, w, h: int) =
  let f = open(filename, fmWrite)
  defer: f.close()
  f.write("P6\n" & $w & " " & $h & "\n255\n")
  discard f.writeBuffer(data, w*h*3)

when isMainModule:
  import os

  if paramCount() < 2:
    echo "Usage: ", getAppFilename(), " input.png output.ppm"
    quit(1)

  var w, h, n: cint
  let img = stbi_load(paramStr(1), addr w, addr h, addr n, 3)
  if img == nil:
    quit("Failed to load image")

  savePPM(paramStr(2), img, w, h)
  stbi_image_free(img)
  echo "Saved: ", paramStr(2)
