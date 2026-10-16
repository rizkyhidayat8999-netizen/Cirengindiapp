#!/usr/bin/env python3
"""Synchronize 31 photographed catalogue products with cirengindi.com.

Each SKU uses its real website photo. Standardized ivory studio framing,
color adjustment, native Cireng Indi logo and no generative changes to food,
packaging, variant quantities or labels.
"""
from __future__ import annotations

import io
import time
import urllib.error
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageOps, ImageDraw, ImageFilter

ROOT=Path("apps/member/app/src/main/assets/assets")
BRAND=ROOT/"logo_cireng_indi.png"
SOURCE="https://cirengindi.com/assets/images/products/"
VERSION="?v=20260829-client-final"
PRODUCTS=[
"cireng","cireng-isi","cilok","sempol-ayam","tahu-bakso","pempek-ikan-tenggiri",
"chicken-katsu","nugget-ayam","bola-ayam-keju","bitterballen","bakso-ayam","ebi-furai",
"baceman-frozen","ayam-ungkep","dimsum-crispy","rollade-ayam","kebab-pisang","kebab-daging",
"corndog","churros","kentang-goreng","frozen-mix-platter","jamu-manjakani","jamu-komplit",
"jamu-kunyit-asam","jamu-jahe-latte","jamu-jahe-original","sari-kacang-hijau","puding-mix",
"salad-jelly","rengginang",
]
if len(PRODUCTS)!=31 or len(set(PRODUCTS))!=31:
    raise RuntimeError("Invalid official catalogue map")

def download(slug:str)->Image.Image:
    url=SOURCE+slug+".webp"+VERSION
    error=None
    for n in range(3):
        try:
            req=urllib.request.Request(
                url,headers={"User-Agent":"Mozilla/5.0 (compatible; CirengIndiStudio/1.0)",
                             "Accept":"image/avif,image/webp,image/*;q=0.8"}
            )
            with urllib.request.urlopen(req,timeout=28) as resp:
                data=resp.read(12_000_000)
                if resp.status!=200 or len(data)<1000:
                    raise RuntimeError(f"Invalid source response {resp.status} {len(data)}")
            image=ImageOps.exif_transpose(Image.open(io.BytesIO(data))).convert("RGB")
            if image.width<250 or image.height<250:raise RuntimeError(f"Source too small: {image.size}")
            return image
        except Exception as exc:
            error=exc
            time.sleep(1+n*2)
    raise RuntimeError(f"Official source failed for {slug}: {error}")

def backdrop(size:int=900):
    # Smooth cream background; not a blurred, magnified photo.
    y,x=np.mgrid[0:size,0:size]
    brightness=4.5*np.maximum(0.0,1-(x-size*.47)**2/(size*.85)**2-(y-size*.18)**2/(size*1.15)**2)
    rgb=np.stack([247+brightness,238+brightness,227+brightness],axis=2)
    return Image.fromarray(np.uint8(np.clip(rgb,0,255)),"RGB").convert("RGBA")

def tone(image:Image.Image)->Image.Image:
    image=ImageEnhance.Color(image).enhance(.95)
    image=ImageEnhance.Contrast(image).enhance(1.055)
    image=ImageEnhance.Brightness(image).enhance(1.025)
    r,g,b=image.split()
    r=r.point(lambda v: min(255,round(v*1.012)))
    b=b.point(lambda v: round(v*.988))
    return Image.merge("RGB",(r,g,b))

def make(slug:str, logo:Image.Image, out:Path):
    original=download(slug)
    photo=tone(original)
    stage=backdrop()
    # Uniform placement without cropping product labels; retain full source photo.
    rect=(35,111,865,866)
    w,h=rect[2]-rect[0],rect[3]-rect[1]
    frame=ImageOps.contain(photo,(w,h),Image.Resampling.LANCZOS)
    frame=frame.filter(ImageFilter.UnsharpMask(radius=.9,percent=65,threshold=3)).convert("RGBA")
    # Gentle shadow around the authentic photo area, not synthetic food.
    cx=rect[0]+(w-frame.width)//2
    cy=rect[1]+(h-frame.height)//2
    mask=Image.new("L",frame.size,0)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,frame.width-1,frame.height-1),radius=25,fill=255)
    shadow=Image.new("RGBA",stage.size,(0,0,0,0))
    ImageDraw.Draw(shadow).rounded_rectangle((cx+3,cy+10,cx+frame.width+3,cy+frame.height+10),radius=29,fill=(80,52,30,37))
    stage.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(17)))
    stage.paste(frame,(cx,cy),mask)
    # Same genuine logo, centered at top. Never redraw lettering with AI.
    badge=logo.copy()
    badge.thumbnail((96,96),Image.Resampling.LANCZOS)
    stage.alpha_composite(badge,((stage.width-badge.width)//2,8))
    out.parent.mkdir(parents=True,exist_ok=True)
    stage.convert("RGB").save(out,format="WEBP",quality=89,method=6)
    with Image.open(out) as check:
        assert check.size==(900,900),out
    print(f"OK {slug}: {original.width}x{original.height} -> {out.name} ({out.stat().st_size:,} bytes)",flush=True)

def main():
    logo=Image.open(BRAND).convert("RGBA")
    # Files are named using immutable source keys to avoid duplicates and category mistakes.
    for i,slug in enumerate(PRODUCTS,1):
        make(slug,logo,ROOT/f"official_{i:02d}.webp")
    done=list(ROOT.glob("official_??.webp"))
    assert len(done)==31,(len(done),done)
    print("PASS: All 31 distinct official product photos harmonized",flush=True)
if __name__=="__main__":main()
