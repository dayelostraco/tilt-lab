#!/usr/bin/env python3
"""Decode a VPX capture frame to PNG.

VPX's -CaptureAttract writes frames in QOI format regardless of the
extension it gives them, and Pillow has no QOI reader, so this decodes it
directly. QOI is simple enough that a reader is shorter than a dependency.

Used to look at the rendered table from macOS with no headset attached:

    tools/capture-frame.ps1 <mode>   on the Windows host
    scp the frame back
    tools/qoi-to-png.py <frame>

Writes <name>-full.png and <name>-crop.png, the latter cropped to the apron
where the training DMD sits. This is how the display was verified: a
successful property assignment proves nothing about what renders.
"""
import struct, pathlib, sys
from PIL import Image
src = pathlib.Path(sys.argv[1])
d = src.read_bytes(); assert d[:4]==b"qoif"
w,h,ch,cs = struct.unpack(">IIBB", d[4:14])
px=bytearray(w*h*4); idx=[(0,0,0,0)]*64; r,g,b,a=0,0,0,255; p,o=14,0; end=len(d)-8
while o<w*h*4 and p<end:
    byte=d[p]; p+=1
    if byte==0xFE: r,g,b=d[p],d[p+1],d[p+2]; p+=3
    elif byte==0xFF: r,g,b,a=d[p],d[p+1],d[p+2],d[p+3]; p+=4
    elif byte>>6==0: r,g,b,a=idx[byte&0x3F]
    elif byte>>6==1:
        r=(r+((byte>>4)&3)-2)&255; g=(g+((byte>>2)&3)-2)&255; b=(b+(byte&3)-2)&255
    elif byte>>6==2:
        b2=d[p]; p+=1; vg=(byte&0x3F)-32
        r=(r+vg-8+((b2>>4)&15))&255; g=(g+vg)&255; b=(b+vg-8+(b2&15))&255
    else:
        run=(byte&0x3F)+1
        for _ in range(run): px[o:o+4]=bytes((r,g,b,a)); o+=4
        continue
    idx[(r*3+g*5+b*7+a*11)%64]=(r,g,b,a); px[o:o+4]=bytes((r,g,b,a)); o+=4
img=Image.frombytes("RGBA",(w,h),bytes(px))
img.save(src.with_name("dmd-shot-full.png"))
c=img.crop((int(w*0.20),int(h*0.68),int(w*0.80),int(h*0.95)))
c=c.resize((c.width*2,c.height*2),Image.LANCZOS); c.save(src.with_name("dmd-crop.png"))
print("ok", c.size)
