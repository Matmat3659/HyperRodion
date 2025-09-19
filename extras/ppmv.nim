import os, strutils, math

proc rgbFg(r,g,b:int): string =
  "\e[38;2;" & $r & ";" & $g & ";" & $b & "m"

proc rgbBg(r,g,b:int): string =
  "\e[48;2;" & $r & ";" & $g & ";" & $b & "m"

proc reset(): string = "\e[0m"

proc loadPPM(filename: string): (int,int,seq[(int,int,int)]) =
  var f = open(filename, fmRead)
  defer: f.close()

  # header
  let magic = f.readLine().strip()
  if magic != "P6":
    quit("Not a binary PPM (P6) file")

  # skip comments
  var line = f.readLine().strip()
  while line.len > 0 and line[0] == '#':
    line = f.readLine().strip()

  let parts = line.splitWhitespace()
  let w = parseInt(parts[0])
  let h = parseInt(parts[1])

  let maxval = parseInt(f.readLine().strip())
  if maxval != 255: quit("Only maxval=255 supported")

  # read raw RGB
  var data: seq[(int,int,int)] = @[]
  for i in 0 ..< w*h:
    let r = f.readChar().ord
    let g = f.readChar().ord
    let b = f.readChar().ord
    data.add((r,g,b))

  return (w,h,data)

proc resizeImage(w,h:int, img:seq[(int,int,int)], newW:int): (int,int,seq[(int,int,int)]) =
  if newW >= w: return (w,h,img)

  let aspectRatio = float(h) / float(w)
  let charAspect = 1.0    # characters are taller than wide → need more height
  let newH = max(1, int(round(float(newW) * aspectRatio * charAspect)))

  var newImg: seq[(int,int,int)] = newSeq[(int,int,int)](newW*newH)

  for y in 0..<newH:
    for x in 0..<newW:
      let srcX = int(float(x) / float(newW) * float(w))
      let srcY = int(float(y) / float(newH) * float(h))
      newImg[y*newW + x] = img[srcY*w + srcX]

  return (newW,newH,newImg)

when isMainModule:
  if paramCount() < 1:
    quit("Usage: " & getAppFilename() & " <image.ppm>")

  let filename = paramStr(1)
  var (w,h,img) = loadPPM(filename)

  # manual width/height
  let newW = 45    # set desired width here
  let newH = 40    # set desired height here

  # resize image exactly to these dimensions
  proc forceResize(w,h:int, img:seq[(int,int,int)], newW,newH:int): (int,int,seq[(int,int,int)]) =
    var newImg: seq[(int,int,int)] = newSeq[(int,int,int)](newW*newH)
    for y in 0..<newH:
      for x in 0..<newW:
        let srcX = int(float(x) / float(newW) * float(w))
        let srcY = int(float(y) / float(newH) * float(h))
        newImg[y*newW + x] = img[srcY*w + srcX]
    return (newW,newH,newImg)

  (w,h,img) = forceResize(w,h,img,newW,newH)

  # use half-blocks
  var y = 0
  while y < h:
    for x in 0..<w:
      let (r1,g1,b1) = img[y*w + x]
      let (r2,g2,b2) = if y+1 < h: img[(y+1)*w + x] else: (0,0,0)
      stdout.write rgbFg(r1,g1,b1) & rgbBg(r2,g2,b2) & "▄"
    echo reset()
    y += 2
