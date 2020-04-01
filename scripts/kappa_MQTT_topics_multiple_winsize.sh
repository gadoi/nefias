#!/bin/bash
# (C) 2020 Steffen Wendzel, wendzel (at) hs-worms (dot) de
#     http://www.wendzel.de
#
# This file is part of NeFiAS.
# 
# NeFiAS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# NeFiAS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Foobar.  If not, see <https://www.gnu.org/licenses/>.
#
# kappa_MQTT_topics_multiple_winsize.sh: calculate Kappa compressibility
# score based on MQTT topics of flows for different window sizes.
# This script receives the following parameters: ./script [chunk] [jobname]

source "`dirname $0`/nefias_lib.sh"
NEFIAS_INIT_PER_FLOW $1 $2 "ip"

WINDOWSIZES="100 500 750 1000 1500 1750 2000 2500"

for windowsize in $WINDOWSIZES; do
	for flow in $FLOWS; do
		# always get the first $windowsize packets of that flow and calculate the kappa value based on frame.time_relative.
echo "DEBUG: grepping flow=>>>$flow<<<"
		cat ${TMPPKTSFILE} | grep $flow | awk -F\, ${FLOWFIELDS} -vwinsize=${windowsize} \
		'BEGIN{ previous=0; output=""; counter=0 }
		{
			if ($mqtt_topic != "" && counter < winsize) {
				i=0
				found=0
				topic_number=0
	#			print "checking for "$mqtt_topic" ..."
				for (i in topics) {
					if (topics[i] == $mqtt_topic) {
	#					print "found (" i ")"
						found=1
						topic_number=i
					}
				}
				if (found == 0) {
	#				print "   not found. adding."
					# add the new topic
					topics[length(topics)+1]=$mqtt_topic
					topic_number=length(topics)
	#				print "      len of topics[] is now "length(topics)
				}
				output = output topic_number
				counter++;
			}			
		}
		END {
			# make sure the window is filled with enough pkts (max defined by head -n)
			if (counter >= winsize) print output;
		}' > ${TMPWORKFILE}
	#	echo -n ">>>"; cat ${TMPWORKFILE}; echo "<<<"
		gzip -9 --no-name --keep ${TMPWORKFILE}
		S_len=`/bin/ls -l ${TMPWORKFILE} | awk '{print $5}'`
		if [ "$S_len" = "0" ]; then
			# too few elements (less than window size)
			touch ${TMPRESULTSFILE} # just let NEFIAS know that we did our job here (create the file, if not present)
		else
			C_len=`/bin/ls -l ${TMPWORKFILE}.gz | awk '{print $5}'`
			K=`echo "scale=6;($S_len/$C_len)" | bc`
			echo "${flow},WinSize=${windowsize},K=${K}" >> ${TMPRESULTSFILE} # Temporary storage for results until all entries were calculated
			#echo "${flow}, K=${K}"
		fi
		rm -f ${TMPWORKFILE} ${TMPWORKFILE}.gz
	done
done

NEFIAS_FINISH

