#!/usr/bin/env python3
"""Cireng Indi image studio: crop real legacy photos, standardize ivory background and genuine logo.
Never fabricate food, packaging, or labels. Reproducible from original legacy git revision.
"""
from pathlib import Path
from PIL import Image, ImageOps, ImageEnhance, ImageFilter, ImageDraw
import numpy as np
import subprocess, tempfile, sys

BASE=Path("apps/member/app/src/main/assets/assets")
SOURCE_REV="cc5ecab96a99be28a60e706c08f8e0c07d85f31f"
CROPS={
"ayam_ungkep":(166,125,556,515),"baceman":(97,140,632,675),
"bakso_ayam":(185,176,540,531),"bitterballen":(97,140,632,675),
"bola_keju":(70,117,646,693),"chicken_katsu":(170,202,539,571),
"churros":(185,166,537,518),"cilok":(152,137,572,557),
"cireng":(210,301,508,599),"cireng_isi":(211,308,506,603),
"corndog":(197,196,526,525),"dimsum":(105,100,640,635),
"ebi":(106,108,642,644),"jahe":(195,189,540,534),
"jamu":(195,147,548,500),"jamu_manis":(202,206,536,540),
"kebab":(92,94,634,636),"kentang":(185,166,537,518),
"mix":(175,149,539,513),"nugget":(159,126,565,532),
"pempek":(210,301,508,599),"puding":(97,100,644,647),
"rengginang":(182,174,542,534),"rollade":(84,113,643,672),
"sempol":(187,164,536,513),"tahu_bakso":(185,205,535,555),
}
BANNERS=["banner_reseller.webp","banner_churros.webp","banner_cafe.webp","banner_puding.webp"]
def legacy_file(name):
    path=(BASE/name).as_posix()
    return subprocess.check_output(["git","show",f"{SOURCE_REV}:{path}"])
def base_canvas(w,h):
    yy=np.arange(h,dtype=np.float32)[:,None];xx=np.arange(w,dtype=np.float32)[None,:]
    bloom=np.clip(1-((xx-.47*w)/(.93*w))**2-((yy-.1*h)/(1.2*h))**2,0,1)
    rgb=np.array([248.,239.,228.])[None,None,:]+bloom[:,:,None]*np.array([5.,6.,7.])[None,None,:]
    return Image.fromarray(np.clip(rgb,0,255).astype("uint8"),"RGB").convert("RGBA")
def warm(photo):
    photo=ImageEnhance.Color(photo.convert("RGB")).enhance(.91)
    photo=ImageEnhance.Contrast(photo).enhance(1.035)
    photo=ImageEnhance.Brightness(photo).enhance(1.045)
    r,g,b=photo.split()
    return Image.merge("RGB",(r.point(lambda x:min(255,int(x*1.012))),g,b.point(lambda x:int(x*.981))))
def rounded(size,radius):
    mask=Image.new("L",size)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,size[0]-1,size[1]-1),radius,fill=255)
    return mask
def open_legacy(name,temp):
    file=temp/name
    file.write_bytes(legacy_file(name))
    return Image.open(file).convert("RGBA")
def put_logo(board,logo,size,top):
    x=logo.copy();x.thumbnail((size,size),Image.Resampling.LANCZOS)
    board.alpha_composite(x,((board.width-x.width)//2,top))
def render_product(name,key,temp,logo):
    raw=open_legacy(name,temp)
    crisp=warm(raw.crop(CROPS[key]))
    board=base_canvas(720,720)
    shadow=Image.new("RGBA",board.size);p=ImageDraw.Draw(shadow)
    p.rounded_rectangle((42,119,678,690),radius=30,fill=(67,43,28,70))
    board.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(15)))
    ImageDraw.Draw(board).rounded_rectangle((39,110,681,688),radius=28,fill="#FFFDF9",outline="#DCCBBA",width=2)
    fitted=ImageOps.fit(crisp,(620,554),method=Image.Resampling.LANCZOS,centering=(.5,.5))
    fitted=fitted.filter(ImageFilter.UnsharpMask(radius=1.25,percent=87,threshold=3)).convert("RGBA")
    board.paste(fitted,(50,121),rounded(fitted.size,21))
    put_logo(board,logo,77,15)
    board.convert("RGB").save(BASE/name,"WEBP",quality=88,method=6)
def render_banner(name,temp,logo):
    raw=warm(open_legacy(name,temp))
    board=base_canvas(1200,620)
    image=ImageOps.fit(raw,(1120,455),method=Image.Resampling.LANCZOS).convert("RGBA")
    board.paste(image,(40,130),rounded(image.size,30))
    put_logo(board,logo,100,15)
    board.convert("RGB").save(BASE/name,"WEBP",quality=87,method=6)
def main():
    with tempfile.TemporaryDirectory() as tmp:
        temp=Path(tmp)
        logo=open_legacy("logo_cireng_indi.png",temp)
        for key in sorted(CROPS):
            name="product_"+key+".webp"
            render_product(name,key,temp,logo)
            print("rendered",name,flush=True)
        for name in BANNERS:
            render_banner(name,temp,logo);print("rendered",name,flush=True)
    assert len(list(BASE.glob("product_*.webp")))==26
if __name__=="__main__":main()
