#!/bin/bash
#
# License
#
# Rips a DVD to MPEG2-PS preserving chapters and subtitles.
# Copyright (c) 2009 Flexion.Org, http://flexion.org/
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

IFS=$'\n'
VER="1.0"

echo "DVD-to-MPG v${VER} - Rips a DVD to MPEG2-PS preserving chapters and subtitles."
echo "Copyright (c) 2009 Flexion.Org, http://flexion.org. MIT License" 
echo

function usage {
    echo
    echo "Usage"
    echo "  ${0} /dev/dvd [--iso] [--keep] [--shrink] [--help]"
    echo ""
    echo "You can also pass the following optional parameters"
    echo "  --iso    : Create an ISO image of the ripped DVD."
    echo "  --keep   : Keep the intermediate files produced during the rip."
    echo "  --shrink : Shrink output so it fits on a single layer DVD-/+R disk."
    echo "  --help   : This help."
    echo
    exit 1
}

# Define the commands we will be using. If you don't have them, get them! ;-)
REQUIRED_TOOLS=`cat << EOF
bc
cat
cut
composite
convert
dvdauthor
dvddirdel
echo
egrep
grep
head
lsdvd
mencoder
mkfifo
mkisofs
mktemp
mplayer
mplex
mv
rm
sed
spumux
stat
subtitle2pgm
tail
tccat
tcextract
M2VRequantiser
EOF`

for REQUIRED_TOOL in ${REQUIRED_TOOLS}
do
    which ${REQUIRED_TOOL} >/dev/null
        
    if [ $? -eq 1 ]; then
        echo "ERROR! \"${REQUIRED_TOOL}\" is missing. ${0} requires it to operate."
        echo "       Please install \"${REQUIRED_TOOL}\"."
        exit 1
    fi        
done

# Get the first parameter passed in and validate it.
if [ $# -lt 1 ]; then
    echo "ERROR! ${0} requires a path to a DVD device or directory as input"	   
	usage
elif [ "${1}" == "-h" ] || [ "${1}" == "--h" ] || [ "${1}" == "-help" ] || [ "${1}" == "--help" ] || [ "${1}" == "-?" ]; then
    usage
else    
    DVD_DEVICE=${1}        
    # Does the DVD deive/path exist?
    if [ -e "${DVD_DEVICE}" ] || [ -d "${DVD_DEVICE}" ] ; then
        # DVD device/path is valid
        shift    
    else    
        echo "ERROR! The DVD device or path provided, \"${DVD_DEVICE}\", does not exist."
        usage
    fi	        
fi

# Init optional parameters.
SHRINK=0
ISO=0
KEEP_FILES=0

# Check for optional parameters
while [ $# -gt 0 ]; 
do
	case "${1}" in
		-s|--shrink|-shrink)
            SHRINK=1
            shift;; 
        -i|--iso|-iso)
        	ISO=1
        	shift;; 
        -k|--keep|-keep)
        	KEEP_FILES=1
        	shift;;         	
        -h|--h|-help|--help|-?)
            usage;;
       	*)
            echo "ERROR! \"${1}\" is not s supported parameter."
            usage;;
	esac   
done

# Get the DVD name and video properties with lsdvd
DVD_INFO=`mktemp`
lsdvd -x ${DVD_DEVICE} > ${DVD_INFO}
DVD_TITLE=`grep "Longest track:" ${DVD_INFO} | cut -f2 -d':' | sed 's/ //g'`
DVD_NAME=`grep "Disc Title:" ${DVD_INFO} | cut -f2 -d':' | sed 's/ //g'`

TITLE_INFO=`mktemp`
lsdvd -x -t ${DVD_TITLE} ${DVD_DEVICE} > ${TITLE_INFO}

# Video format, PAL or NTSC
VIDEO_FORMAT=`grep "VTS: ${DVD_TITLE}" ${DVD_INFO} | cut -d':' -f5 | cut -d',' -f1 | sed 's/ //g' | tr [A-Z] [a-z]`

# Video aspect ratio, 4:3 or 16:9
VIDEO_AR=`grep "VTS: ${DVD_TITLE}" ${DVD_INFO} | cut -d':' -f6 | cut -d',' -f1 | sed 's/ //g' | sed 's-/-:-g'`
# What are the widescreen options.
VIDEO_DF=`grep "VTS: ${DVD_TITLE}" ${DVD_INFO} | cut -d':' -f9 | cut -d',' -f1 | sed 's/ //g'`

# Get some useful information from mplayer and store it in a temp file
STREAM_INFO=`mktemp`
mplayer -quiet -nojoystick -nolirc -dvd-device ${DVD_DEVICE} dvd://${DVD_TITLE} -vo null -ao null -frames 0 -identify > ${STREAM_INFO}

# Strip the first 0 from the DVD_TITLE so it is now mplayer compatible.
DVD_TITLE=`echo ${DVD_TITLE} | sed 's/0//'`

# Get the first video track
VIDEO_TRACK=`grep "ID_VIDEO_ID" ${STREAM_INFO} | head -n1 | cut -d'=' -f2`
VIDEO_WIDTH=`grep "ID_VIDEO_WIDTH" ${STREAM_INFO} | cut -d'=' -f2`
VIDEO_HEIGHT=`grep "ID_VIDEO_HEIGHT" ${STREAM_INFO} | cut -d'=' -f2`

# Get the last audio track id (MPEG) format then convert it the to numeric format.
AUDIO_TRACK=`grep "ID_AUDIO_ID" ${STREAM_INFO} | tail -n1 | cut -d'=' -f2`
AUDIO_TRACK=`grep "aid: ${AUDIO_TRACK}" ${STREAM_INFO} | cut -d' ' -f3 | sed 's/ //g'`

# Exclude MPEG-1 LayerII audio streams as 'tcextract' doesn't support them.
AUDIO_STREAMS=`grep "aid:" ${STREAM_INFO} | grep -v mpeg1`
if [ -z "${AUDIO_STREAMS}" ]; then
    echo "ERROR! This DVD doesn't have any supported audio streams, exitting."
    exit 1
fi

# Determine the video widescreen options for dvdauthor
VIDEO_OPTS=""
if [ "${VIDEO_DF}" == "Letterbox" ]; then
	VIDEO_OPTS="+nopanscan"
elif [ "${VIDEO_DF}" == "P&S" ]; then
	VIDEO_OPTS="+noletterbox"
elif [ "${VIDEO_DF}" == "P&S + Letter" ]; then
	VIDEO_OPTS=""
else
	ASPECT_RATIO=`echo "scale=2; ${VIDEO_WIDTH}/${VIDEO_HEIGHT}" | bc`
	if [ "${ASPECT_RATIO}" == "1.25" ]; then
		VIDEO_OPTS="+nopanscan"
	fi
fi

# Display the available audio streams and ask the user to pick one.
echo
echo "Available audio streams"
for AUDIO_STREAM in ${AUDIO_STREAMS}
do
    echo " - ${AUDIO_STREAM}"
done
echo
read -p "Select the audio stream number you want to use [${AUDIO_TRACK}]: " AUDIO_TRACK_USER

# Validate the audio track selected by the user.
AUDIO_TRACK_VALIDATE=`grep "audio stream: ${AUDIO_TRACK_USER}" ${STREAM_INFO}`

# Is the user selected audio track valid
if [ -n "${AUDIO_TRACK_VALIDATE}" ] && [ -n "${AUDIO_TRACK_USER}" ]; then
    # User selected audio is valid
    AUDIO_TRACK=${AUDIO_TRACK_USER}
    AUDIO_TRACK_DETAILS=`grep "audio stream: ${AUDIO_TRACK_USER}" ${STREAM_INFO}`
    echo "Using ${AUDIO_TRACK_DETAILS}"
else
    # User selected audio is invalid
    AUDIO_TRACK_DETAILS=`grep "audio stream: ${AUDIO_TRACK}" ${STREAM_INFO}`
    echo "Using ${AUDIO_TRACK_DETAILS}"
fi

# Get the format of the select audio track so we can name the ripper file appropriately
AUDIO_FORMAT=`grep "audio stream: ${AUDIO_TRACK}" ${STREAM_INFO} | cut -d':' -f3 | cut -d'(' -f1 | sed 's/ //g'`
AUDIO_LANG=`grep "audio stream: ${AUDIO_TRACK}" ${STREAM_INFO} | cut -d':' -f4 | cut -d' ' -f2 | sed 's/ //g'`
# Change lpcm to pcm
if [ "${AUDIO_FORMAT}" == "lpcm" ]; then
    AUDIO_FORMAT="pcm"
fi

SUBS_STREAMS=`grep "Subtitle:" ${TITLE_INFO} | sed 's/\t//g'`
# Display the available audio streams and ask the user to pick one.
echo
echo "Available subtitle streams"
for SUBS_STREAM in ${SUBS_STREAMS}
do
    echo " - ${SUBS_STREAM}"
done
echo
read -p "Select the subtitle stream id you want to use: " SUBS_TRACK_USER

# Validate the subtitle track selected by the user.
SUBS_TRACK_VALIDATE=`grep "Stream id: ${SUBS_TRACK_USER}" ${TITLE_INFO}`

# Is the user selected subtitle track valid
if [ -n "${SUBS_TRACK_VALIDATE}" ] && [ -n "${SUBS_TRACK_USER}" ]; then
    # User selected audio is valid
    SUBS_TRACK=${SUBS_TRACK_USER}
    SUBS_TRACK_DETAILS=`grep "Stream id: ${SUBS_TRACK_USER}" ${TITLE_INFO} | sed 's/\t//g'`
    echo "Using ${SUBS_TRACK_DETAILS}"
    
    SUBS_LANG=`grep "Stream id: ${SUBS_TRACK}" ${TITLE_INFO} | cut -d':' -f3 | cut -d' ' -f2`

    # Get the subtitle palette
	# TODO - Select an appropriate subtitle palette
	# Typically "-c 255,255,0,255" generally works best.
	#	I have made this color combination the default
	#	but many DVD need other color combinations. 
	#	One of these options should work for you:
	#	  -c 255,0,255,255
	#	  -c 255,255,0,255
	#	  -c 255,255,255,0
	#	  -c 0,255,255,255	
	SUBS_PALETTE="255,255,0,255"	
else
    echo "No subtitles selected"
    SUBS_TRACK=""
fi

# Get chapter and angle details
DVD_TITLE_CHAPTERS=`grep ID_DVD_TITLE_${DVD_TITLE}_CHAPTERS} ${STREAM_INFO} | cut -d'=' -f2`
DVD_TITLE_ANGLES=`grep ID_DVD_TITLE_${DVD_TITLE}_ANGLES ${STREAM_INFO} | cut -d'=' -f2`
DVD_TITLE_CHAPTER_POINTS=`grep CHAPTERS: ${STREAM_INFO} | sed 's/CHAPTERS: //' | sed 's/,$//'`
   
# Remove temp files
rm ${DVD_INFO}
rm ${TITLE_INFO}
rm ${STREAM_INFO}

# Setup some variables
AUDIO_FILE=${DVD_NAME}.${AUDIO_FORMAT}
VIDEO_FILE=${DVD_NAME}.m2v
MPLEX_FILE=${DVD_NAME}.mpg
SUBS_FILE=${DVD_NAME}.ps1
SUBS_DIR=${DVD_NAME}_SUBS
XML_FILE=${DVD_NAME}.dvdxml
ISO_FILE=${DVD_NAME}.iso
AUDIO_FIFO=`mktemp`
VIDEO_FIFO=`mktemp`
QUANT_FIFO=`mktemp`
MPLEX_FIFO=`mktemp`
SUBS_FIFO=`mktemp`

# Create the FIFOs
rm ${AUDIO_FIFO} ${VIDEO_FIFO} ${QUANT_FIFO} ${MPLEX_FIFO} ${SUBS_FIFO} 2>/dev/null
mkfifo ${AUDIO_FIFO} 
mkfifo ${VIDEO_FIFO}
mkfifo ${QUANT_FIFO}
mkfifo ${MPLEX_FIFO}
mkfifo ${SUBS_FIFO}

# Get the audio FIFO ready and background the extractor
tcextract -i ${AUDIO_FIFO} -a ${AUDIO_TRACK} -t vob -x ${AUDIO_FORMAT} > ${AUDIO_FILE} &

# Get the video FIFO ready and background the extractor
tcextract -i ${VIDEO_FIFO} -a ${VIDEO_TRACK} -t vob -x mpeg2 > ${VIDEO_FILE} &

# Get the subs FIFO ready and background the extractor    
if [ "${SUBS_TRACK}" != "" ]; then
    tcextract -i ${SUBS_FIFO} -a ${SUBS_TRACK} -t vob -x ps1 > ${SUBS_FILE} &
fi

# Start extracting the streams by flooding the FIFOs
if [ "${SUBS_TRACK}" != "" ]; then  
    tccat -i ${DVD_DEVICE} -T ${DVD_TITLE},-1,${DVD_TITLE_ANGLE} -P | tee ${AUDIO_FIFO} ${VIDEO_FIFO} ${SUBS_FIFO} > /dev/null
else
    tccat -i ${DVD_DEVICE} -T ${DVD_TITLE},-1,${DVD_TITLE_ANGLE} -P | tee ${AUDIO_FIFO} ${VIDEO_FIFO} > /dev/null
fi

# Scale the subtitles
if [ "${SUBS_TRACK}" != "" ]; then	 
	# Convert subtitles to grey scale PNG with alpha
    subtitle2pgm -i ${SUBS_FILE} -o ${DVD_NAME} -g 4 -t 1 -C 4 -c ${SUBS_PALETTE} -P
	
    # Create a canvas for the subtitles    
	CANVAS_FILE="transparent-${VIDEO_WIDTH}x${VIDEO_HEIGHT}.png"
	convert -size ${VIDEO_WIDTH}x${VIDEO_HEIGHT} xc:transparent ${CANVAS_FILE}

	# Calcuate the vertical offset for subtitle repositioning
	RESIZE_HEIGHT=`echo "${VIDEO_HEIGHT}/5" | bc`    
	RESIZE_FILE="resize-${VIDEO_WIDTH}x${RESIZE_HEIGHT}.png"
	convert -size ${VIDEO_WIDTH}x120 xc:transparent ${RESIZE_FILE}
	
	# Scale all the subtitles to the correct resolution.
	for SUBS_IMAGE in ${DVD_NAME}*.png
	do
		# Hmm, I'm sure this could be optimised....	
		echo "Scaling image: ${SUBS_IMAGE}"
		# Resize the subtitles to offset them from the bottom of the picture.
		composite -gravity north -compose copy "${SUBS_IMAGE}" ${RESIZE_FILE} temp.png		
		# Scale the resized subtitles
		composite -gravity south -compose copy temp.png ${CANVAS_FILE} "${SUBS_IMAGE}"						
	done			
	rm temp.png 2>/dev/null
fi

# Shrink the video
if [ ${SHRINK} -eq 1 ]; then
    # Calculate the requantisation factor
    VIDEO_SIZE=`stat -c%s "${VIDEO_FILE}"`
    AUDIO_SIZE=`stat -c%s "${AUDIO_FILE}"`

    # Calcualte the available DVD5 space for the video.
    if [ "${SUBS_TRACK}" != "" ]; then
        SUBS_SIZE=`stat -c%s "${SUBS_FILE}"`
        REQUANT_SPACE=`echo "4700000000-${AUDIO_SIZE}-${SUBS_SIZE}" | bc`
    else
        REQUANT_SPACE=`echo "4700000000-${AUDIO_SIZE}" | bc`                
    fi

    REQUANT_RATIO=`echo "scale=2; ${VIDEO_SIZE}/${REQUANT_SPACE}" | bc`
    # This is the requantisation factor, the closer to 1.00 the better. 
    # TODO - is 1.04 an optimal scaler instead of 1.05?
    REQUANT_FACTOR=`echo "scale=2; ${REQUANT_RATIO}*1.05" | bc`
    # Less than 1.00 means no shrinkage required.
    REQUANT_REQUIRED=`echo "${REQUANT_FACTOR} > 1.00" | bc`

    # Shrink the video if required.
    if [ "${REQUANT_REQUIRED}" == "1" ]; then
        echo "Shrinking video."
        REQUANT_TOO_HIGH=`echo "${REQUANT_FACTOR} > 1.50" | bc`
        if [ "${REQUANT_TOO_HIGH}" == "1" ]; then
            echo "WARNING! Requantisation factor is high. Quality will suffer!"
        fi        
        
        # tcrequant corrupts video on 64-bit system.
        #tcrequant -d2 -i ${VIDEO_FILE} -o ${QUANT_FILE} -f ${REQUANT_FACTOR}
        
        #Create a FIFO and use it with 'mplex' to reduce disk usage and I/O.
		M2VRequantiser ${REQUANT_FACTOR} ${VIDEO_SIZE} < ${VIDEO_FILE} > ${QUANT_FIFO} &
    else
        echo "No video shrinking required."
        SHRINK=0
    fi
fi    

# Multiplex the output
if [ ${SHRINK} -eq 1 ]; then
    # Shrink was requested and required, mplex the requantised video stream.
    if [ "${SUBS_TRACK}" != "" ]; then    
        mplex -M -f 8 -o ${MPLEX_FIFO} ${QUANT_FIFO} ${AUDIO_FILE} &
    else
        mplex -M -f 8 -o ${MPLEX_FILE} ${QUANT_FIFO} ${AUDIO_FILE}
    fi        
    # Adds subtitles if any were selected.
    if [ "${SUBS_TRACK}" != "" ]; then
	    # Multiplex the subtitles from the FIFO
        spumux -m dvd -s 0 ${XML_FILE} < ${MPLEX_FIFO} > ${MPLEX_FILE}
    fi	
else
    # Shrink was not required, mplex the original video stream.
    if [ "${SUBS_TRACK}" != "" ]; then    
        mplex -M -f 8 -o ${MPLEX_FIFO} ${VIDEO_FILE} ${AUDIO_FILE} &
    else
        mplex -M -f 8 -o ${MPLEX_FILE} ${VIDEO_FILE} ${AUDIO_FILE}
    fi        
    # Adds subtitles if any were selected.
    if [ "${SUBS_TRACK}" != "" ]; then    
	    # Multiplex the subtitles from the FIFO
        spumux -m dvd -s 0 ${XML_FILE} < ${MPLEX_FIFO} > ${MPLEX_FILE}
    fi    
fi    

# Remove transient files, if required.
if [ ${KEEP_FILES} -eq 0 ]; then
    rm ${AUDIO_FILE} 2>/dev/null
    rm ${VIDEO_FILE} 2>/dev/null
    rm ${SUBS_FILE} 2>/dev/null                
    rm ${XML_FILE} 2>/dev/null
    rm ${CANVAS_FILE} 2>/dev/null                
    rm ${RESIZE_FILE} 2>/dev/null                    
    rm ${DVD_NAME}*.png 2>/dev/null    
fi    

if [ ${ISO} -eq 1 ]; then
    # Create Video DVD tileset
    if [ "${SUBS_TRACK}" != "" ]; then
        dvdauthor -t -o ${DVD_NAME} -a ${AUDIO_FORMAT}+${AUDIO_LANG} -v ${VIDEO_FORMAT}+${VIDEO_AR}+${VIDEO_WIDTH}x${VIDEO_HEIGHT}${VIDEO_OPTS} -c ${DVD_TITLE_CHAPTER_POINTS} ${MPLEX_FILE} -s ${SUBS_LANG}         
    else
        dvdauthor -t -o ${DVD_NAME} -a ${AUDIO_FORMAT}+${AUDIO_LANG} -v ${VIDEO_FORMAT}+${VIDEO_AR}+${VIDEO_WIDTH}x${VIDEO_HEIGHT}${VIDEO_OPTS} -c ${DVD_TITLE_CHAPTER_POINTS} ${MPLEX_FILE}
    fi
    
    # Create Video DVD index
    dvdauthor -o ${DVD_NAME} -T
    
    # Remove transient file, if required.
    if [ ${KEEP_FILES} -eq 0 ]; then
        rm ${MPLEX_FILE} 2>/dev/null
    fi        
    
    # Create ISO image
    mkisofs -dvd-video -udf -V ${DVD_NAME} -o ${ISO_FILE} ${DVD_NAME}
    
    # Remove transient directory
    if [ ${KEEP_FILES} -eq 0 ]; then
        dvddirdel -o ${DVD_NAME}
    fi            
fi

# Remove FIFO files
rm ${AUDIO_FIFO} ${VIDEO_FIFO} ${QUANT_FIFO} ${MPLEX_FIFO} ${SUBS_FIFO} 2>/dev/null    

echo "All Done!"
