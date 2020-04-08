#!/bin/bash
set -eux
car=$1
shift
cdr=$@
# machinectl requires absolute path
exec machinectl shell user@ $(which $car) $cdr
