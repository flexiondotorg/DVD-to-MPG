#!/bin/bash

function build {
    RELEASE_NAME="DVD-to-MPG"
    RELEASE_VER="1.1"
    RELEASE_DESC="Rips a DVD to MPEG-2 PS or MPEG-2 TS"
    RELEASE_KEYWORDS="DVD, rip, ripper, Linux, script, chapters, requant, subtitles, DVD5, MPEG2, MPEG-2 PS, MPEG-2 TS, H.264, PS3, Xbox 360"

    rm ${RELEASE_NAME}-v${RELEASE_VER}.tar* 2>/dev/null
    bzr export ${RELEASE_NAME}-v${RELEASE_VER}.tar
    tar --delete -f ${RELEASE_NAME}-v${RELEASE_VER}.tar ${RELEASE_NAME}-v${RELEASE_VER}/build.sh
    gzip ${RELEASE_NAME}-v${RELEASE_VER}.tar
}
