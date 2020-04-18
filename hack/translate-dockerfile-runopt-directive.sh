#!/bin/bash
# From https://raw.githubusercontent.com/rootless-containers/usernetes/v20200309.0/hack/translate-dockerfile-runopt-directive.sh

# Input:
#   FROM ...
#   ...
#   # runopt = --mount=type=cache,target=/root/.cache
#   RUN foo

# Output:
#   # syntax = docker/dockerfile:1-experimental
#   FROM ...
#   ...
#   RUN --mount=type=cache,target=/root/.cache foo

echo '# syntax = docker/dockerfile:1-experimental'

last_runopt=""
while IFS="" read -r line || [[ -n $line ]]; do
	run=$(echo $line | grep -ioP '^\s*RUN\s+\K.+')
	printed=""
	if [[ -n $run && -n $last_runopt ]]; then
		echo "RUN $last_runopt $run"
		printed=1
	fi
	last_runopt=$(echo $line | grep -ioP '^#\s*runopt\s*=\s*\K.+')
	if [[ -z $last_runopt && -z $printed ]]; then
		echo "$line"
	fi
done
