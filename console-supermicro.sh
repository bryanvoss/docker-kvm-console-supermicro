#!/bin/bash

# Copyright 2016 Internap.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	 http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export NAME="internap/ipmi-novnc-console"

_console_supermicro() {
	docker build -t ${NAME} $(dirname ${0}) || return ${?}

	if [ 0 = ${#} ] || [ 3 -lt ${#} ] ; then
		echo 'usage: console-supermicro.sh <host> [username] [password]'
		return 
	fi

	id=$(docker run -P -d -e IPMI_ADDRESS=${1} -e IPMI_USERNAME=${2-ADMIN} -e IPMI_PASSWORD=${3-ADMIN} ${NAME})
	if [ "" = "${id}" ] ; then
		echo could not get containter id:
		docker ps | grep ${NAME}
		return 1
	fi

	sleep 2

	local port=$( docker port $id 8080 | sed 's,.*:,,' )
	local url="http://localhost:${port}/vnc.html?host=localhost&port=${port}&autoconnect=true&password=no-password&logging=debug"
	echo ${url} | sed 's,.,-,g'
	echo ${url}
	echo ${url} | sed 's,.,-,g'

	echo hit enter to stop the container
	read

	docker rm --force ${id}

	echo bye
}

_console_supermicro ${*}
