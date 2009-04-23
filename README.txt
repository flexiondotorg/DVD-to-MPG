License

Rips a DVD to MPEG2-PS preserving chapters and subtitles.
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
DVD movies so we can avoid that crap.

I run a Mediatomb DLNA server and I want to load it with all my DVDs. Ripping 
them helps reduce the amount of storage I will require. MPEG2-PS files are 
compatible with my PS3 which is the client to my Mediatomb DLNA server.

As a solution to the above I created this script, which can extract the main 
feature from a DVD video, allowing the user to select one audio stream and one
subtitle stream. Optionally the video can be requantised and an ISO image 
created. If creating an ISO image the chapters are also preserved from the 
original. 

Usage

  ./DVD-to-MPG.sh /dev/dvd [--iso] [--keep] [--shrink] [--help]

You can also pass the following optional parameters
  --iso    : Create an ISO image of the ripped DVD.
  --keep   : Keep the intermediate files produced during the rip.
  --shrink : Shrink output so it fits on a single layer DVD-/+R disk.
  --help   : This help.

The resulting .ISO can be tested with gmplayer or vlc to check that the 
video, audio, subtitle, chapters, etc are also working correctly.

 gmplayer -dvd-device DVD_VIDEO.iso dvd://
 vlc DVD_VIDEO.iso

Requirements

 - bc, cat, cut, composite, convert, dvdauthor, dvddirdel, echo, egrep, grep,
   head, lsdvd, mkfifo, mkisofs, mktemp, mplayer, mplex, mv, rm, sed, spumux,   
   stat, subtitle2pgm, tail, tccat, tcextract, which, M2VRequantiser.
   
Known Limitations

 - DVDs with ARccOS or other intentional sector corruption are not supported.
 - No user selection of which title to rip. Defaults to the longest title.
 - Rips one video, one audio stream and one subtitle stream from the source DVD.
 - Multi-angle titles are not properly supported yet.
 - Subtitles are converted to grey scale, a single the palette is hard coded.
 - Subtitle conversion is relatively and could doubtless be optimised.

Source Code

You can checkout the current branch from my Bazaar repository. This is a 
read-only repository, get in touch if you want to contribute and require write 
access.

 bzr co http://code.flexion.org/Bazaar/DVD-to-MPG/

References

 - http://www.linuxquestions.org/questions/linuxanswers-discussion-27/discussion-dvd9-to-dvd5-guide-253747/
 - http://www.usenet-forums.com/linux-general/79033-copy-dvd-linux.html
 - http://polarwave.blogspot.com/2007/09/more-multimedia.html

v1.0 2009, 23rd April.

 - Initial release
