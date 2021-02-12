#!/bin/bash

# Copyright 2016 Internap.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export PROTOCOL="https"

_main() {
	#############################################################################
	# get the session id

	local login_url="${PROTOCOL}://${IPMI_ADDRESS}/cgi/login.cgi"
	echo "fetching the session id from ${login_url}"

	session_id=$(get_session_id)
	if [ -z "${session_id}" ]; then
		echo "could not fetch the session id with ${PROTOCOL}, trying http"
		export PROTOCOL="http"
	  	session_id=$(get_session_id)
	fi
	if [ -z "${session_id}" ]; then
		echo "could not get the session id with https or http"
		exit 1
	fi

	set -e
	set -o pipefail

	#############################################################################
	# Download jnlp
	echo Download jnlp

	mkdir -p "workspace-${IPMI_ADDRESS}"
	cd "workspace-${IPMI_ADDRESS}"
	jnlp_url="${PROTOCOL}://${IPMI_ADDRESS}/cgi/url_redirect.cgi?url_name=ikvm&url_type=jwsk"
	curl -s --insecure "${jnlp_url}" -H 'Referer: http://localhost' -H "Cookie: ${session_id}" > launch.jnlp 
	if [ 0 != ${?} ] ; then
		echo failed to download from ${jnlp_url} 
		exit 2
	fi

	# Download resource
	echo Download resource

	codebase_url=$(xmlstarlet sel -t -v '/jnlp/@codebase' launch.jnlp)
	jars="$(xmlstarlet sel -t -v 'concat(//*/jar/@href, //*/jar/@version)' launch.jnlp | sed 's/.jar\(..*\)$/__V\1.jar/g')"
	query='@os="'"$(uname | sed 's/Darwin/Mac OS X/')"'" and @arch="'"$(uname -m)"'"'
	libs="$(xmlstarlet sel -t -v 'concat(//*/resources['"$query"']/nativelib/@href, //*/nativelib[position()]/@version)' launch.jnlp | sed 's/.jar\(..*\)$/__V\1.jar/g')"

	for resource in $jars $libs; do
		url="${codebase_url}/${resource}.pack.gz"
		if [ -f ${resource} ] ; then
			echo already downloaded ${resource}: $( ls -l ${resource} )
		else
			tmp_file="viewer-app.tmp"
			echo downloading $resource from ${url}
			curl --insecure -L -H 'Referer: http://localhost' -H "Cookie: ${session_id}" ${url} > ${tmp_file} || exit 3
			echo 
			ls -l ${tmp_file}
			echo unpack
			unpack200 ${tmp_file} $resource || return 
			echo unpacked
			
		fi
		#[ -f $resource ] || curl --insecure -L -H 'Referer: http://localhost' -H "Cookie: ${session_id}" "${codebase_url}/${resource}.pack.gz" | unpack200 - $resource
	done

	# Extract libraries
	echo Extract libraries

	for lib in $libs; do
		unzip -o $lib > /dev/null || exit 4
	done

	# Start application
	echo Start application

	java_vm_args=$(xmlstarlet sel -t -v '//*/j2se/@java-vm-args' launch.jnlp || true)
	main_class=$(xmlstarlet sel -t -v '//*/application-desc/@main-class' launch.jnlp)
	arguments=$(xmlstarlet sel -t -v '//*/application-desc/argument' launch.jnlp)
	exec java -Djava.library.path=. -cp $(echo $jars|tr ' ' ':') $java_vm_args $main_class $arguments
}

get_session_id() {
	local username=${IPMI_USERNAME:-ADMIN}
	local password=${IPMI_PASSWORD:-ADMIN}

	local login_url="${PROTOCOL}://${IPMI_ADDRESS}/cgi/login.cgi"
	curl --connect-timeout 2 --insecure -s -X POST "${login_url}" --data "name=${username}&pwd=${password}" -i \
	| awk '/SID=[^;]/ { print $2 }'
}

_main
