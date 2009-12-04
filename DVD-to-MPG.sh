#!/bin/bash
#
# License
#
# Rips a DVD to MPEG-2 PS or MPEG-2 TS.
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
VER="1.1"

echo "DVD-to-MPG v${VER} - Rips a DVD to MPEG-2 PS or MPEG-2 TS."
echo "Copyright (c) 2009 Flexion.Org, http://flexion.org. MIT License" 
echo

function usage {
    echo
    echo "Usage"
    echo "  ${0} /dev/dvd [--iso] [--m2ts] [--keep] [--shrink] [--help]"
    echo ""
    echo "You can also pass the following optional parameters"
    echo "  --iso    : Create an ISO image of the ripped DVD.    (Implies MPEG-2 PS)"
    echo "  --m2ts   : Create a MPEG-2 TS file with H.264 video. (Subtitles not supported)"
    echo "  --keep   : Keep the intermediate files produced during the rip."
    echo "  --shrink : Shrink the video stream so that:"
    echo "               * MPEG-2 PS fits on a single layer DVD-/+R disk."
    echo "               * MPEG-2 TS is two pass encoded as H.264 at a bitrate of 2816."    
    echo "  --help   : This help."
    echo
    exit 1
}

# Define the commands we will be using. If you don't have them, get them! ;-)
REQUIRED_TOOLS=`cat << EOF
aften
bc
cat
cut
dcadec
dvdauthor
dvddirdel
echo
grep
head
ifo_dump
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
spuunmux
stat
subtitle2vobsub
tail
tccat
tcextract
tsMuxeR
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
M2TS=0
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
        	M2TS=0
        	shift;; 
        -m|--m2ts|-m2ts)
        	M2TS=1
        	ISO=0
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
VIDEO_FPS=`grep "ID_VIDEO_FPS" ${STREAM_INFO} | cut -d'=' -f2 | sed s'/.000//'`
# Get the length of the video in secs and half it.
VIDEO_LENGTH=`grep "ID_LENGTH" ${STREAM_INFO} | cut -d'=' -f2 | cut -d'.' -f1`
VIDEO_MIDDLE=`echo ${VIDEO_LENGTH}/2 | bc`

# Get the aspect ratio.
VIDEO_ASPECT=`grep Movie-Aspect ${STREAM_INFO} | grep -v undefined`
VIDEO_ASPECT=${VIDEO_ASPECT#Movie-Aspect is }
VIDEO_ASPECT=${VIDEO_ASPECT%:1 - prescaling*}

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

SUBS_STREAMS=`grep "Subtitle:" ${TITLE_INFO} | sed 's/\t//g' | grep -v Unknown`
if [ -n "${SUBS_STREAMS}" ] && [ ${M2TS} -eq 0 ]; then

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
    else
        echo "No subtitles selected"
        SUBS_TRACK=""
    fi
else
    SUBS_TRACK=""        
fi
# Get chapter and angle details
DVD_TITLE_CHAPTERS=`grep ID_DVD_TITLE_${DVD_TITLE}_CHAPTERS} ${STREAM_INFO} | cut -d'=' -f2`
DVD_TITLE_ANGLES=`grep ID_DVD_TITLE_${DVD_TITLE}_ANGLES ${STREAM_INFO} | cut -d'=' -f2`
DVD_TITLE_CHAPTER_POINTS=`grep CHAPTERS: ${STREAM_INFO} | sed 's/CHAPTERS: //' | sed 's/,$//'`
   
# Remove temp files
rm ${DVD_INFO} 2>/dev/null
rm ${TITLE_INFO} 2>/dev/null
rm ${STREAM_INFO} 2>/dev/null

# Setup some variables
AUDIO_FILE=${DVD_NAME}.${AUDIO_FORMAT}
VIDEO_FILE=${DVD_NAME}.m2v
MPLEX_FILE=${DVD_NAME}.mpg
SUBS_FILE=${DVD_NAME}.ps1
SUBS_PAL=${DVD_NAME}.yuv
XML_FILE=${DVD_NAME}.xml
ISO_FILE=${DVD_NAME}.iso
META_FILE=${DVD_NAME}.meta
CROP_FILE=${DVD_NAME}.crop
PASS_FILE=${DVD_NAME}.pass
X264_FILE=${DVD_NAME}.h264
M2TS_FILE=${DVD_NAME}.m2ts
AUDIO_FIFO=`mktemp`
VIDEO_FIFO=`mktemp`
QUANT_FIFO=`mktemp`
MPLEX_FIFO=`mktemp`
SUBS_FIFO=`mktemp`

# Only re-extract the audio, video and subs if they do not all ready exist.
if [ ! -f ${AUDIO_FILE} ] && [ ! -f ${VIDEO_FILE} ]; then
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
else
    echo "WARNING! Skipping audio, video and subtitle ripping as the files already exist."
fi

# If creating MPEG-2 PS then convert subtitles for use with dvdauthor
if [ "${SUBS_TRACK}" != "" ] && [ ${M2TS} -eq 0 ]; then	 
    SUBS_SIZE=`stat -c%s "${SUBS_FILE}"`
    if [ ${SUBS_SIZE} -ne 0 ]; then 
        # Get the subtitle palette (yuv)
        ifo_dump ${DVD_DEVICE} ${DVD_TITLE} | grep Color | head -n 16 | sed 's/Color ..: 00//' > ${SUBS_PAL}
        subtitle2vobsub -p ${SUBS_FILE} -o ${DVD_NAME} -s ${VIDEO_WIDTH}x${VIDEO_HEIGHT}
        spuunmux -o ${DVD_NAME} -p ${SUBS_PAL} ${DVD_NAME}.sub 
    else
        echo "WARNING! Subtitles were ripped but are zero bytes. Ignoring subtitles."
        SUBS_TRACK=""
    fi	    
fi

# Shrink the video
if [ ${SHRINK} -eq 1 ]; then
    # Calculate the requantisation factor
    VIDEO_SIZE=`stat -c%s "${VIDEO_FILE}"`
    AUDIO_SIZE=`stat -c%s "${AUDIO_FILE}"`

    if [ ${M2TS} -eq 1 ]; then
        mplayer "${VIDEO_FILE}" -aspect ${VIDEO_ASPECT} -nolirc -nojoystick -quiet -ss ${VIDEO_MIDDLE} -speed 100 -frames 480 -identify -nosound -vo null -ao null -vfm ffmpeg,libmpeg2 -vf cropdetect > ${CROP_FILE} 2>&1
        VIDEO_CROP=`grep "Crop area" ${CROP_FILE} | tail -n1 | cut -d'(' -f2 | sed 's/)\.//' | sed s'/-vf //'`
	echo ${VIDEO_CROP}
        CROP_WIDTH=`echo ${VIDEO_CROP} | cut -d'=' -f2 | cut -d':' -f1`
        CROP_HEIGHT=`echo ${VIDEO_CROP} | cut -d'=' -f2 | cut -d':' -f2`
        
        CROP_WIDTH_OK=`echo "scale=2; ${CROP_WIDTH}/16" | bc | cut -d'.' -f2`
        CROP_HEIGHT_OK=`echo "scale=2; ${CROP_HEIGHT}/16" | bc | cut -d'.' -f2`        

        if [ "${CROP_WIDTH_OK}" == "00" ] && [ "${CROP_HEIGHT_OK}" == "00" ]; then
            echo "GOOD! Cropping width (${CROP_WIDTH}) and height (${CROP_HEIGHT}) are both a multiple of 16."
        else
            echo "ERROR! Cropping width (${CROP_WIDTH}) and height (${CROP_HEIGHT}) must both be a multiple of 16."
            exit
        fi
        
        # Software Scalers (sws) are:
        #  0    fast bilinear
        #  1    bilinear
        #  2    bicubic (good quality) (default)
        #  3    experimental
        #  4    nearest neighbor (bad quality)
        #  5    area
        #  6    luma bicubic / chroma bilinear
        #  7    gauss
        #  8    sincR
        #  9    lanczos
        #  10   natural bicubic spline

        # Software Scalers results are:
        #  0    produces acceptable results
        #  1    produces blurred images
        #  2    produces very good images
        #  7    is even worse than -sws 1
        #  8    produces shadows near strong edges and increases contrast
        #  9/10 produce the fewest artifacts and gives even a bit better
        #       results than -sws 2
        
        # References
        #  - http://www.mplayerhq.hu/DOCS/HTML/en/menc-feat-x264.html
        #  - http://www.wieser-web.de/MPlayer/sws1/
        #  - http://lists.mplayerhq.hu/pipermail/mplayer-users/2003-October/038642.html

        X264_COMMON="bitrate=2816:bframes=3:b_bias=0:merange=16:direct_pred=auto:level=4.1:mixed_refs:weight_b:8x8dct:threads=auto"
        X264_PASS1="pass=1:turbo=2:ref=1:me=dia:cabac=0:trellis=0:subme=1:b_adapt=1"
        X264_PASS2="pass=2:turbo=0:ref=5:me=umh:cabac=1:trellis=1:subme=7:b_adapt=0"

        echo "1st Pass"
        eval mencoder "${VIDEO_FILE}" -vfm ffmpeg,libmpeg2 -nosound -of rawvideo -ovc x264 -vf pp=fd,${VIDEO_CROP},softskip,harddup -sws 0  -x264encopts ${X264_COMMON}:${X264_PASS1} -passlogfile ${PASS_FILE} -noskip -o /dev/null 2>/dev/null

        echo "2nd Pass"
        eval mencoder "${VIDEO_FILE}" -vfm ffmpeg,libmpeg2 -nosound -of rawvideo -ovc x264 -vf pp=fd,${VIDEO_CROP},softskip,harddup -sws 10 -x264encopts ${X264_COMMON}:${X264_PASS2} -passlogfile ${PASS_FILE} -noskip -o ${X264_FILE} 2>/dev/null
    else
        # Calcualte the available DVD5 space for the video.
        if [ "${SUBS_TRACK}" != "" ]; then
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
                echo "WARNING! Requantisation factor of ${REQUANT_FACTOR} is high. Quality will suffer!"
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
fi    

# If we are creating a MPEG-2 TS define the audio language correctly.
if [ ${M2TS} -eq 1 ]; then
    if [ "${AUDIO_LANG}" != '' ]; then
        AUDIOLANG="lang=${AUDIO_LANG}, "
    fi
fi    

# Multiplex the output
if [ ${SHRINK} -eq 1 ]; then
    # Shrink was requested and required, mplex the requantised video stream.
    if [ ${M2TS} -eq 1 ]; then                    
        echo "MUXOPT --no-pcr-on-video-pid --new-audio-pes --vbr --vbv-len=500" > ${META_FILE}        
        echo "V_MPEG4/ISO/AVC, \"${X264_FILE}\", fps=${VIDEO_FPS}, level=4.1, insertSEI, contSPS, ar=As source, track=${VIDEO_TRACK}" >> ${META_FILE}        

        # Add audio stream.
        if [ "${AUDIO_FORMAT}" == "ac3" ]; then
            # We have AC3, no need to transcode.
            echo "A_AC3, \"${AUDIO_FILE}\", ${AUDIOLANG}track=${AUDIO_TRACK}" >> ${META_FILE}
        elif [ "${AUDIO_FORMAT}" == "dts" ]; then   
            # We have DTS, transcoding required.
            DOLBY_FIFO=`mktemp`
            rm ${DOLBY_FIFO} 2>/dev/null
            mkfifo ${DOLBY_FIFO}    
            dcadec -o wavall "${AUDIO_FILE}" | aften -b 640 -v 0 -readtoeof 1 - "${DOLBY_FIFO}" &
            echo "A_AC3, \"${DOLBY_FIFO}\", ${AUDIOLANG}track=${AUDIO_TRACK}" >> ${META_FILE}
        else
            echo "ERROR! ${AUDIO_FORMAT} is not supported in MPEG-2 TS file."
            exit                        
        fi                        
        tsMuxeR ${META_FILE} ${M2TS_FILE}        
    else
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
    fi        
else
    # Shrink was not required, mplex the original video stream.
    if [ ${M2TS} -eq 1 ]; then                                  
        echo "MUXOPT --no-pcr-on-video-pid --vbr --vbv-len=500" > ${META_FILE}            
        echo "V_MPEG-2, \"${VIDEO_FILE}\", fps=${VIDEO_FPS}, track=${VIDEO_TRACK}" >> ${META_FILE}        

        # Add audio stream.
        if [ "${AUDIO_FORMAT}" == "ac3" ]; then
            # We have AC3, no need to transcode.
            echo "A_AC3, \"${AUDIO_FILE}\", ${AUDIOLANG}track=${AUDIO_TRACK}" >> ${META_FILE}
        elif [ "${AUDIO_FORMAT}" == "dts" ]; then   
            # We have DTS, transcoding required.
            DOLBY_FIFO=`mktemp`
            rm ${DOLBY_FIFO} 2>/dev/null
            mkfifo ${DOLBY_FIFO}    
            dcadec -o wavall "${AUDIO_FILE}" | aften -b 640 -v 0 -readtoeof 1 - "${DOLBY_FIFO}" &
            echo "A_AC3, \"${DOLBY_FIFO}\", ${AUDIOLANG}track=${AUDIO_TRACK}" >> ${META_FILE}
        else
            echo "ERROR! ${AUDIO_FORMAT} is not supported in MPEG-2 TS file."
            exit            
        fi                        
        tsMuxeR ${META_FILE} ${M2TS_FILE} 
    else   
        if [ "${SUBS_TRACK}" != "" ]; then    
            mplex -M -f 8 -o ${MPLEX_FIFO} ${VIDEO_FILE} ${AUDIO_FILE} &
        else
            mplex -M -f 8 -o ${MPLEX_FILE} ${VIDEO_FILE} ${AUDIO_FILE}
        fi        
        # Adds subtitles if any were selected.
        if [ "${SUBS_TRACK}" != "" ]; then    
	        # Multiplex the subtitles from the FIFO
            spumux -m dvd -P -s 0 ${XML_FILE} < ${MPLEX_FIFO} > ${MPLEX_FILE}
        fi    
    fi        
fi    

# Remove transient files, if required.
if [ ${KEEP_FILES} -eq 0 ]; then
    rm ${AUDIO_FILE} 2>/dev/null
    rm ${VIDEO_FILE} 2>/dev/null
    rm ${SUBS_FILE} 2>/dev/null                
    rm ${SUBS_PAL} 2>/dev/null                    
    rm ${DVD_NAME}.sub 2>/dev/null                    
    rm ${DVD_NAME}.idx 2>/dev/null                    
    rm ${XML_FILE} 2>/dev/null
    rm ${CROP_FILE} 2>/dev/null                            
    rm ${PASS_FILE}* 2>/dev/null                                
    rm ${X264_FILE} 2>/dev/null        
    rm ${META_FILE} 2>/dev/null                                
fi    

# Change the permission on the M2TS file(s) to something sane.
if [ ${M2TS} -eq 1 ]; then
    chmod 644 ${M2TS_FILE} 2>/dev/null   
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
rm ${AUDIO_FIFO} ${VIDEO_FIFO} ${QUANT_FIFO} ${MPLEX_FIFO} ${SUBS_FIFO} ${DOLBY_FIFO} 2>/dev/null    

echo "All Done!"
