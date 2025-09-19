# HyperRodion v0.3.2
# HyperRodion: small Hyperfine-like/clone CLI in Nim (new stuff and fixes update)
# Compile: nim c -d:release hyperrodion.nim

import os, osproc, strutils, sequtils, math, times

# --- High-resolution timer ---
type
  Timespec* = object
    tv_sec*: clong
    tv_nsec*: clong

const
  CLOCK_MONOTONIC* = 1

proc clock_gettime*(clk_id: cint, tp: ptr Timespec): cint
  {.importc: "clock_gettime", header: "<time.h>".}

proc nowCoarse(): float =
  float(epochTime())

proc nowPrecise(): float =
  var ts: Timespec
  if clock_gettime(CLOCK_MONOTONIC, addr ts) == 0:
    return float(ts.tv_sec) + float(ts.tv_nsec) / 1e9
  else:
    return nowCoarse()

# --- Colors ---
const
  RESET   = "\x1b[0m"
  BOLD    = "\x1b[1m"
  GREEN   = "\x1b[32m"
  YELLOW  = "\x1b[33m"
  CYAN    = "\x1b[36m"
  MAGENTA = "\x1b[35m"

# --- Options ---
var
  runs = 10
  precise = false
  verbose = false
  disableAutoCleanup = false
  prepareCmd = ""
  command = ""

proc printUsage() =
  echo "Usage: hypernim [options] -- command"
  echo "Options:"
  echo "  -t, --times N               Number of runs (default: 10)"
  echo "  -p, --precise               Use high-resolution timer"
  echo "  -v, --verbose               Show full command output"
  echo "  --prepare CMD               Command to run before each benchmark run"
  echo "  --disable-autocleanup, -dac Disable auto-cleanup"
  echo "  -h, --help                  Show this help"
  quit(0)

# --- CLI Parse ---
var idx = 1
while idx <= paramCount():
  let a = paramStr(idx)
  case a
  of "-h","--help": printUsage()
  of "-p","--precise": precise = true; idx.inc()
  of "-v","--verbose": verbose = true; idx.inc()
  of "-t","--times":
    if idx+1 > paramCount(): quit "Missing value for " & a
    runs = parseInt(paramStr(idx+1)); idx += 2
  of "--prepare":
    if idx+1 > paramCount(): quit "Missing value for --prepare"
    prepareCmd = paramStr(idx+1); idx += 2
  of "-dac","--disable-autocleanup":
    disableAutoCleanup = true; idx.inc()
  of "--times=":
    runs = parseInt(a.split("=")[1]); idx.inc()
  of "--": # command begins
    var rem: seq[string] = @[]
    for j in idx+1..paramCount(): rem.add(paramStr(j))
    command = rem.join(" "); break
  else:
    if a.startsWith("--"): quit "Unknown option: " & a
    var rem: seq[string] = @[]
    for j in idx..paramCount(): rem.add(paramStr(j))
    command = rem.join(" "); break

if command.len == 0:
  printUsage()  # falls back to showing help instead of "No command provided."

if runs < 1:
  quit "--times must be >= 1"

# --- Helpers ---
proc runOnce(cmd: string, showOutput: bool): int =
  if showOutput: execShellCmd(cmd)
  else: execShellCmd(cmd & " > /dev/null 2>&1")

proc showProgressLine(done,total:int,avg:float) =
  let width=30
  let filled=(done*width) div total
  let bar="=".repeat(filled) & " ".repeat(width-filled)
  let pct=int(float(done)/float(total)*100.0)
  let avgR=(round(avg*1_000_000.0)/1_000_000.0)
  stdout.write("\r[" & bar & "] " & $pct & "% - " & $avgR &
               " sec - (" & $done & "/" & $total & ")")
  flushFile(stdout)

proc smartCleanup(cmd: string) =
  if disableAutoCleanup: return
  if cmd.startsWith("cp "):
    let parts = cmd.splitWhitespace()
    if parts.len >= 3:
      let src = parts[1]
      let dst = parts[^1]
      let home = getEnv("HOME", ".")
      let tmpdir = home / ".tmp"
      if dst != src and dst.startsWith(tmpdir):
        try:
          if fileExists(dst): removeFile(dst)
          elif dirExists(dst): removeDir(dst)
        except OSError: discard

# --- Main ---
var durations: seq[float] = @[]

echo BOLD & CYAN & "Command:" & RESET, " ", command
if prepareCmd.len > 0: echo CYAN & "Prepare: " & RESET & prepareCmd
if precise: echo YELLOW & "Using high-resolution timer" & RESET
if verbose: echo YELLOW & "Verbose mode: full output" & RESET

let home = getEnv("HOME",".")
let tmpdir = home / ".tmp"
if not dirExists(tmpdir): createDir(tmpdir)

for r in 1..runs:
  if prepareCmd.len > 0: discard runOnce(prepareCmd, verbose)

  if verbose: echo MAGENTA & "\nRun " & $r & "/" & $runs & ":" & RESET & " Running: " & command
  let start = if precise: nowPrecise() else: nowCoarse()
  let rc = runOnce(command, verbose)
  let stop = if precise: nowPrecise() else: nowCoarse()
  let elapsed = stop - start
  durations.add(elapsed)

  if verbose:
    echo "Run ",r,": ",elapsed," sec"
    if rc != 0: echo "\n\033[31mWarning:\033[0m exited with ",rc
  else:
    let avgSoFar = durations.sum / float(durations.len)
    showProgressLine(r,runs,avgSoFar)

  smartCleanup(command)

if not verbose: stdout.write("\n")

let mean = durations.sum / float(durations.len)
let stddev = sqrt(durations.mapIt((it-mean)*(it-mean)).sum / float(durations.len))

echo "\n" & BOLD & "Summary:" & RESET
echo GREEN & "Min:   " & RESET & $(durations.min) & " sec"
echo GREEN & "Max:   " & RESET & $(durations.max) & " sec"
echo YELLOW & "Mean:  " & RESET & $mean & " sec"
echo YELLOW & "Stddev:" & RESET & $stddev & " sec"
