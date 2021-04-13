#!/bin/bash	

export DISPLAY=:1

_clipster_main() {
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
	
	local xoff=$( echo ${clip} | cut -f2 -d+ )
	local yoff=$( echo ${clip} | cut -f3 -d+ )

	echo "clipster: winid is ${winid} and clip is ${clip}"

	for ((i=0;i<1;i--)) ; do
		local consoleSize=$( xdotool getwindowgeometry ${winid} | awk '/Geometry:/{print $NF}' )
		local w=$( echo ${consoleSize} | cut -f1 -dx )
		local h=$( echo ${consoleSize} | cut -f2 -dx )
		let wo=${w}-${xoff}
		let ho=${h}-${yoff}
		local nuClip="${wo}x${ho}+${xoff}+${yoff}"

		#echo "${clip} vs ${nuClip} from ${consoleSize} and ${xoff},${yoff}"
		if [ "${nuClip}" = "${clip}" ] ; then
			echo "the clip is still ${clip}" >/dev/null
		else
			echo "update the clip to ${nuClip}"
			x11vnc -rfbauth /tmp/vnc-password.txt -remote "clip:${nuClip}" --sync
			local status=${?}
			if [ 0 = ${status} ] ; then
				clip=${nuClip}
				echo "clipped to ${clip}: ${status}"
			else
				echo "could not clip to ${clip}: ${status}"
			fi
		fi
		sleep 1
	done
}

_clipster_main ${*}
