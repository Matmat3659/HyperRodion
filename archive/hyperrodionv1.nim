# HyperRodion v1
# HyperRodion: small Hyperfine-like/clone CLI in Nim (precision, verbose, progress, colors update)
# Compile: nim c -d:release hyperrodionv1.nim

import os, osproc, strutils, sequtils, math, times    # <-- added 'times' because i forgot

# --- High-resolution timer via clock_gettime ---
type
  Timespec* = object
    tv_sec*: clong
    tv_nsec*: clong

const
  CLOCK_MONOTONIC* = 1

proc clock_gettime*(clk_id: cint, tp: ptr Timespec): cint {.importc: "clock_gettime", header: "<time.h>".}

proc nowCoarse(): float =
  # fallback coarse seconds
  return float(epochTime())    # epochTime() comes from 'times' module

proc nowPrecise(): float =
  var ts: Timespec
  if clock_gettime(CLOCK_MONOTONIC, addr ts) == 0:
    return float(ts.tv_sec) + float(ts.tv_nsec) / 1e9
  else:
    return nowCoarse()

# --- ANSI colors ---
const
  RESET = "\x1b[0m"
  BOLD  = "\x1b[1m"
  GREEN = "\x1b[32m"
  YELLOW = "\x1b[33m"
  CYAN = "\x1b[36m"
  MAGENTA = "\x1b[35m"

# --- CLI defaults & parsing ---
var
  runs = 10
  precise = false
  verbose = false
  command = ""

proc printUsage() =
  echo "Usage: hypernim [options] -- command"
  echo "Options:"
  echo "  -t, --times N      Number of runs (default: 10)"
  echo "  -p, --precise      Use high-resolution timer (nanoseconds)"
  echo "  -v, --verbose      Verbose: show command before each run and do not hide its output"
  echo "  -h, --help         Show this help"
  quit(0)

var idx = 1
while idx <= paramCount():
  let a = paramStr(idx)
  if a in ["-h","--help"]:
    printUsage()
  elif a in ["-p","--precise"]:
    precise = true
    idx.inc()
  elif a in ["-v","--verbose"]:
    verbose = true
    idx.inc()
  elif a in ["-t","--times"]:
    if idx + 1 > paramCount():
      echo "Error: missing value for ", a
      quit(1)
    try:
      runs = parseInt(paramStr(idx+1))
    except:
      echo "Error: invalid integer for ", a
      quit(1)
    idx += 2
  elif a.startsWith("--times="):
    try:
      runs = parseInt(a.split('=')[1])
    except:
      echo "Error: invalid --times value"
      quit(1)
    idx.inc()
  elif a.startsWith("--"):
    echo "Unknown option: ", a
    quit(1)
  else:
    # join all remaining params into the command string
    var remaining: seq[string] = @[]
    for j in idx..paramCount():
      remaining.add(paramStr(j))
    command = remaining.join(" ")
    break

if command.len == 0:
  echo "Error: no command provided."
  printUsage()

if runs < 1:
  echo "Error: --times must be >= 1"
  quit(1)

# --- Runner ---
proc runOnce(cmd: string, showOutput: bool): int =
  ## Runs `cmd` via the shell and returns its exit code.
  ## If showOutput is false we redirect to /dev/null.
  if showOutput:
    return execShellCmd(cmd)                   # shows output, returns exit code
  else:
    return execShellCmd(cmd & " > /dev/null 2>&1")

proc showProgressLine(done, total: int, avg: float) =
  # single-line progress: [bar] P% - avg - (done/total)
  let width = 30
  let filled = (done * width) div total
  var bar = newStringOfCap(width)
  for _ in 0..<filled: bar.add("=")
  for _ in filled..<width: bar.add(" ")
  let pct = int(float(done) / float(total) * 100.0)
  # round average to microsecond precision display (6 decimals)
  let avgRounded = (round(avg * 1_000_000.0) / 1_000_000.0)
  stdout.write("\r[" & bar & "] " & $pct & "% - " & $(avgRounded) & " sec - (" & $done & "/" & $total & ")")
  flushFile(stdout)

# --- Main loop ---
var durations: seq[float] = @[]

echo BOLD & CYAN & "Command:" & RESET, " ", command
if precise:
  echo YELLOW & "Using high-resolution timer (CLOCK_MONOTONIC)" & RESET
if verbose:
  echo YELLOW & "Verbose mode: command output will be shown." & RESET

for r in 1..runs:
  if verbose:
    echo MAGENTA & "\nRun " & $r & "/" & $runs & ":" & RESET & " Running: " & command
  let start = if precise: nowPrecise() else: nowCoarse()
  let rc = runOnce(command, verbose)
  let stop = if precise: nowPrecise() else: nowCoarse()
  let elapsed = stop - start
  durations.add(elapsed)

  if verbose:
    # verbose mode: show per-run timing and (optionally) warn about non-zero exit
    echo "Run ", r, ": ", $(elapsed), " sec"
    if rc != 0:
      echo "\n\033[31mWarning:\033[0m run ", r, " exited with code ", rc
  else:
    # non-verbose: update a single progress line with average so far
    var totalSoFar = 0.0
    for d in durations: totalSoFar += d
    let avgSoFar = totalSoFar / float(durations.len)
    showProgressLine(r, runs, avgSoFar)

if not verbose:
  stdout.write("\n")

# --- Stats ---
var total = 0.0
for d in durations: total += d
let mean = total / float(durations.len)

var vsum = 0.0
for d in durations:
  let diff = d - mean
  vsum += diff * diff
let stddev = sqrt(vsum / float(durations.len))
let minv = durations.min
let maxv = durations.max

echo "\n" & BOLD & "Summary:" & RESET
echo GREEN & "Min:   " & RESET & $(minv) & " sec"
echo GREEN & "Max:   " & RESET & $(maxv) & " sec"
echo YELLOW & "Mean:  " & RESET & $(mean) & " sec"
echo YELLOW & "Stddev:" & RESET & $(stddev) & " sec"
