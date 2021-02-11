#!/bin/bash -e

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

export DISPLAY=:1

_vnc_server() {
	# Disable the screen saver
	xset s off s reset
	
	local clip=${X11VNC_CLIP-1024x768+0+21}
	read width height x y < <(echo ${clip} | sed 's,[^0-9], ,g')

	local winid=""
	for ((i=0;i<1;i--)) ; do 
		winid=$( xwininfo -root -tree | awk '/Java iKVM Viewer/ { print $1 }' )
		if [ "" != "${winid}" ] ; then
			echo "the iKVM window id is ${winid}"
			break
		fi
		echo "waiting on the iKVM window"
		sleep 1
	done

	echo DISPLAY=:1 xdotool windowmove $winid 0 0 windowfocus $winid windowsize $winid $width $height 
	xdotool \
		windowmove $winid 0 0 \
		windowfocus $winid \
		windowsize $winid $width $height \
	|| echo "error moving the window"

	x11vnc -storepasswd ${VNC_PASSWORD} /tmp/vnc-password.txt

	_run_novnc 2>&1 | tee -a /tmp/novnc.txt &

	echo "the clip as ${clip}"

	exec x11vnc -rfbport 5900 -rfbauth /tmp/vnc-password.txt -ncache 10 --xkb -shared -forever -desktop "${X11VNC_TITLE-}" -clip $clip
}

_run_novnc() {
	for ((i=0;i<1;i--)) ; do
		if [ 0 != $( netstat -tln | grep -wc 5900 ) ] ; then
			echo "vnc server is ready"
			break;
		fi
		echo "vnc server is not ready"
		sleep 1
	done

	echo starting novnc
	supervisorctl start novnc

	sleep 1 
	ps -ef | grep -v grep | egrep '(websockify|novnc)'
}

_vnc_server
