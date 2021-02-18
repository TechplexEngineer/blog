---
title: "Lua Locking"
date: 2021-02-18T07:43:43-05:00
tags : [ lua, til ]
categories : [ "Development" ]
draft: false
---

Recently I found myself needing a way to synchronize access to a file in a lua program. I've previously used `flock` to ensure that multiple instances of my bash script couldn't run at the same time.


I started by writing some bash scripts to test some assumptions `main.sh`:
```bash
#!/bin/bash

set -euo pipefail

# $$ - PID for this process
# $! - PID for last process started (eg. vim &; echo $!)
PID=$$
canRun=$(flock /tmp/mylock ./canRun.sh $PID)


echo "output: $canRun"

# -z means length of string is zero
if [[ -z $canRun ]]
then
    echo "we can run"
else
    echo "lock is held and valid"
    exit 1
fi

# Do the work you came here to do
for i in $(seq 10); do
    echo "$i"
    sleep 1
done

# release the lock
flock /tmp/mylock rm /tmp/mylock
```

On line 9 above, flock command invokes `canRun.sh` which is listed below

```bash {linenos=table,anchorlinenos=true}
#!/bin/bash

set -euo pipefail

PID=$1
lockContent=$(cat /tmp/mylock)

##
## NOTE: printing anything tells the calling program the lock is held
##

err(){
    echo "-- $*" >>/dev/stderr
}

# -z means: string is null, that is, has zero length
# -n means: string is not null
if [[ -n $lockContent ]] && ps -p "$lockContent" > /dev/null
then
    # found PID in file, and it is running
    echo "fail"

else
    # Either: empty lock file or the process is not running
    # claiming lock for $PID
    echo "$PID" > /tmp/mylock
fi
```

Here is the output when running a single instance:
```shell
$ ./main.sh
output: 
we can run
1
2
3
4
5
6
7
8
9
```
If we attempt to run two instances:
```shell
$ ./main.sh &; ./main.sh
[1] 1944233
output: 
we can run
1
output: fail
lock is held and valid
$ 2
3
4
5
6
7
8
9
10

[1]  + 1944233 done       ./main.sh
```
If we start an instance, and kill it with ctrl+c we can start another instance without issue:
```shell
$ ./main.sh
output: 
we can run
1
2
3
4
^C
$ ./main.sh
output: 
we can run
1
2
3
4
^C
```

Now that we have a working example in bash, we can convert it to lua, here is a listing of `main.lua`
```lua
#!/usr/bin/lua

local handle = io.popen("echo $PPID")
local PID = handle:read("*a")
handle:close()


handle = io.popen("flock /tmp/mylock ./canrun.lua "..PID)
local canRun = handle:read("*a")
handle:close()

if canRun == "" then
    print "we can run"
else
    print "lock is held and valid"
    os.exit(1)
end

-- Do the work you came here to do

-------------------------------------------------------------------------------
-- Sample Code Start
-------------------------------------------------------------------------------

-- warning: clock can eventually wrap around for sufficiently large n
-- (whose value is platform dependent).  Even for n == 1, clock() - t0
-- might become negative on the second that clock wraps
local clock = os.clock
local function sleep(n)  -- seconds
  local t0 = clock()
  while clock() - t0 <= n do end
end
for i=1,20 do
    print(i)
    sleep(1)
end
-------------------------------------------------------------------------------
-- Sample Code End
-------------------------------------------------------------------------------

-- release the lock
os.execute('flock /tmp/mylock rm /tmp/mylock')
```

And the implementation of `canrun.lua`:
```lua
#!/usr/bin/lua

-------------------------------------------------------------------------------
--  http://lua-users.org/wiki/FileInputOutput

-- Read an entire file.
-- Use "a" in Lua 5.3; "*a" in Lua 5.1 and 5.2
local function readall(filename)
  local fh = assert(io.open(filename, "rb"))
  local contents = assert(fh:read(_VERSION <= "Lua 5.2" and "*a" or "a"))
  fh:close()
  return contents
end

-- Write a string to a file.
local function write(filename, contents)
  local fh = assert(io.open(filename, "wb"))
  fh:write(contents)
  fh:flush()
  fh:close()
end
-------------------------------------------------------------------------------

local PID=arg[1]
local lockPath='/tmp/mylock'
local lockContent=readall(lockPath)

--
-- NOTE: printing anything tells the calling program the lock is held
--

if lockContent ~= '' and os.execute('ps -p "'..lockContent..'" > /dev/null') == 0 then
    -- found PID in file, and it is running
    print("fail")
else
    -- Either: empty lock file or the process is not running
    -- claiming lock for $PID
    write(lockPath, PID)
end
```
