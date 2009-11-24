License

Rips a DVD to MPEG-2 PS or MPEG-2 TS.
Copyright (c) 2009 Flexion.Org, http://flexion.org/

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Introduction

Every so often I find myself in looking through the ex-rental DVD "bargain bin".
Quite often I find something I consider a bargain. However, the experience of 
watching an ex-rental DVD is typically ruined by the various trailers and 
marketing guff at the start which you can't skip. My wife hates that stuff, and 
I love my wife, so I routinely rip the main feature of newly acquired ex-rental 
DVD movies so we can avoid the marketing crap.

I run a Mediatomb DLNA server and I want to import all my DVDs. Ripping them 
helps reduce the amount of storage I will require. MPEG2-PS and MPEG2-TS files 
are compatible with my PS3 which is the client to my Mediatomb DLNA server.

As a solution to the above I created this script, which can extract the main 
feature from a DVD video, allowing the user to select one audio stream and one
subtitle stream. 

Optionally the video stream can be shrunk. In MPEG-2 PS mode the video is 
requantised and in MPEG-2 TS mode the video is re-encoded as H.264. Requantising
is faster but can introduce artifacting. H.264 encoding is slower, but very good
quality.

Some things to be aware of:

  - MPEG-2 PS is the default mode of operation.
  - Subtitles are only supported in MPEG-2 PS mode.
  - MPEG-2 PS files created by this script are DVD compliant.
  - ISO files created by this script will preserve the chapters from the 
    original DVD.
  - The PS3 can't play DTS audio in MPEG-2 PS streams, unless the MPEG-2 PS has
    been authored to DVD.
  - The PS3 can't play DTS audio in MPEG-2 TS streams, therefore this script 
    will transcode DTS to AC3 when in MPEG-2 TS mode.

Usage

  ./DVD-to-MPG.sh /dev/dvd [--iso] [--m2ts] [--keep] [--shrink] [--help]

You can also pass the following optional parameters
  --iso    : Create an ISO image of the ripped DVD.    (Implies MPEG-2 PS)
  --m2ts   : Create a MPEG-2 TS file with H.264 video. (Subtitles not supported)
  --keep   : Keep the intermediate files produced during the rip.
  --shrink : Shrink the video stream so that:
               * MPEG-2 PS fits on a single layer DVD-/+R disk.
               * MPEG-2 TS is two pass encoded as H.264 at a bitrate of 2816.               
  --help   : This help.

The resulting .ISO can be tested with gmplayer or vlc to check that the 
video, audio, subtitle, chapters, etc are also working correctly.

 gmplayer -dvd-device DVD_VIDEO.iso dvd://
 vlc DVD_VIDEO.iso

Requirements

 - aften, bash, bc, cat, cut, dcadec, dvdauthor, dvddirdel, echo, grep, head, 
   ifo_dump, lsdvd, mkfifo, mkisofs, mktemp, mplayer, mplex, mv, rm, sed, 
   spumux, spuunmux, stat, subtitle2vobsub, tail, tccat, tcextract, tsMuxeR, 
   which, M2VRequantiser.
   
ifo_dump
   
This is how to install ifo_dump on Ubuntu Linux.   
   
 cvs -z3 -d:pserver:anonymous@dvd.cvs.sourceforge.net:/cvsroot/dvd co -P ifodump
 cd ifodump
 mkdir dvdnav
 wget -c "http://dvd.cvs.sourceforge.net/viewvc/*checkout*/dvd/libdvdnav2/src/dvdread/ifo_print.h?revision=1.1.1.1" -O dvdnav/ifo_print.h
 wget -c "http://dvd.cvs.sourceforge.net/viewvc/*checkout*/dvd/libdvdnav2/src/dvdread/ifo_types.h?revision=1.1.1.1" -O dvdnav/ifo_types.h
 wget -c "http://dvd.cvs.sourceforge.net/viewvc/*checkout*/dvd/libdvdnav2/src/dvdread/dvd_reader.h?revision=1.1.1.1 -O dvdnav/dvd_reader.h
 ./autogen
 make
 sudo make install
   
Known Limitations

 - DVDs with ARccOS or other intentional sector corruption are not supported.
 - No user selection of which title to rip. Defaults to the longest title.
 - Rips one video, one audio stream and one subtitle stream from the source DVD.
 - Multi-angle titles are not properly supported yet.

Source Code

You can checkout the current branch from my Bazaar repository. This is a 
read-only repository, get in touch if you want to contribute and require write 
access.

 bzr co http://code.flexion.org/Bazaar/DVD-to-MPG/

References

 - http://www.linuxquestions.org/questions/linuxanswers-discussion-27/discussion-dvd9-to-dvd5-guide-253747/
 - http://www.usenet-forums.com/linux-general/79033-copy-dvd-linux.html
 - http://polarwave.blogspot.com/2007/09/more-multimedia.html

v1.1 2009, 23rd November.

 - Added the option to create MPEG-2 TS rip.
 - Added x264 re-encode if shrinking a MPEG-2 TS rip.
 - Fixed subtitle palette auto detection.
 - Fixed bug with zero byte subtitles.

v1.0 2009, 23rd April.

 - Initial release
