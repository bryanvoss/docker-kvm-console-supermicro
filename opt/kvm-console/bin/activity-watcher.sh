#!/bin/bash	

export EXPRESSION="listener exit due to --idle-timeout"
export LOG_FILE="/var/log/supervisor/novnc.log"

_activity_watcher_main() {
	local status=0

	if [ -f "${LOG_FILE}" ] ; then
		local idle_count=$( grep -c "${EXPRESSION}" "${LOG_FILE}" ) || return ${?}
		_activity_watcher_out "idle:${idle_count},"
		let status=${status}+${idle_count}
	else
		_activity_watcher_out "idle:.,"
	fi

	_activity_watcher_processes
	let status=${status}+${?}

	return ${status}
}

_activity_watcher_processes() {
	ps -ef | awk -v CLOAKED=1 '
		BEGIN {
			n = split( "java novnc vnc wsy", tmp );
			for ( i = 1 ; i <= n ; i++ ) {
				REQUIRED[ tmp[ i ] ] = 0;
			}
		}
		
		/CLOAKED/ {next}

		{ for (i=1;i<8;i++) $i = ""; sub(/^[ \t]*/,""); }

		$2 ~ /launch.sh/   { $1 = "novnc" }
		$3 == "websockify" { $1 = "wsy" }
		$1 == "x11vnc"     { $1 = "vnc" }
		$1 in REQUIRED { REQUIRED[$1]++ }

		END {
			missing = 0;
			for ( x in REQUIRED ) {
				found = REQUIRED[ x ];
				if ( !found ) missing++;
				printf( "%s:%d,", x, found );
			}

			printf( "ms:%d", missing );
			exit( missing );
		}
	'
}

_activity_watcher_out() {
	echo -n "${*}"
}

_activity_watcher_main ${*}
