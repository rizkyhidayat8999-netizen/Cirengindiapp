#!/usr/bin/env python3
"""Deterministic, offline, warm studio thumbnails for all 31 real Cireng Indi SKUs.
Keeps the original product in each image; crops only baked-in blurred margins.
--preview-only prints a before/after sheet as base64 JPG for manual inspection.
--deploy embeds compact WebP thumbnails directly into OTA HTML (no image network).
"""
import argparse,base64,io,re
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter,ImageOps,ImageEnhance
ASSETS=Path('apps/member/app/src/main/assets/assets')
HTML=Path('apps/member/app/src/main/assets/index.html')
BEG='/* CI_NORMALIZED_PHOTO_START */'
END='/* CI_NORMALIZED_PHOTO_END */'
S=208

def sharpness(im):
    img=im.convert('L').resize((100,100),Image.Resampling.BILINEAR)
    scores=[]
    for x in range(3,96):
        scores.append(sum(abs(img.getpixel((x,y))-img.getpixel((x,y+2)))+
            abs(img.getpixel((x,y))-img.getpixel((x+2,y))) for y in range(12,90,3)))
    def avg(a,b):
        z=scores[max(0,a-3):min(93,b-3)]
        return sum(z)/max(len(z),1)
    return avg(36,64)/max(50,(avg(7,24)+avg(78,93))/2)

def make_tile(original):
    original=ImageOps.exif_transpose(original).convert('RGB')
    score=sharpness(original)
    pillar=score>1.38
    if pillar:
        w,h=original.size
        span=int(w*0.50);x=(w-span)//2
        original=original.crop((x,int(h*.035),x+span,int(h*.965)))
    out=Image.new('RGB',(S,S))
    d=ImageDraw.Draw(out)
    top=(255,250,244);bot=(244,230,216)
    for y in range(S):
        t=y/(S-1)
        d.line((0,y,S,y),fill=tuple(round(top[j]*(1-t)+bot[j]*t) for j in range(3)))
    d.ellipse((21,14,185,176),fill=(251,241,230))
    d.ellipse((22,166,186,202),fill=(233,209,186))
    maxw,maxh=(122,174) if pillar else (182,174)
    ratio=min(maxw/original.width,maxh/original.height)
    w=max(1,round(original.width*ratio));h=max(1,round(original.height*ratio))
    item=original.resize((w,h),Image.Resampling.LANCZOS)
    brightness=item.convert('L').resize((1,1)).getpixel((0,0))
    if brightness<89:item=ImageEnhance.Brightness(item).enhance(min(1.22,98/max(brightness,1)))
    x=(S-w)//2;y=(S-h)//2-2
    mask=Image.new('L',(w,h))
    ImageDraw.Draw(mask).rounded_rectangle((0,0,w-1,h-1),radius=10,fill=255)
    shadow=Image.new('RGBA',(w+24,h+24),(0,0,0,0))
    ImageDraw.Draw(shadow).rounded_rectangle((12,12,w+11,h+11),radius=11,fill=(83,45,29,65))
    shadow=shadow.filter(ImageFilter.GaussianBlur(10))
    out.paste(shadow.convert('RGB'),(x-12,y-9),shadow.getchannel('A'))
    out.paste(item,(x,y),mask)
    return out,score,pillar

def pack(tile,limit=4400):
    chosen=b''
    for quality in (76,68,60,52,46,40,34):
        buf=io.BytesIO();tile.save(buf,'WEBP',quality=quality,method=6)
        chosen=buf.getvalue()
        if len(chosen)<=limit:return chosen
    small=tile.resize((176,176),Image.Resampling.LANCZOS)
    for quality in (50,38,30):
        buf=io.BytesIO();small.save(buf,'WEBP',quality=quality,method=6)
        chosen=buf.getvalue()
        if len(chosen)<=limit:return chosen
    return chosen

def main():
    parser=argparse.ArgumentParser()
    mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--preview-only',action='store_true')
    mode.add_argument('--deploy',action='store_true')
    args=parser.parse_args()
    photos={};samples=[]
    for idx in range(1,32):
        source=ASSETS/f'official_{idx:02d}.webp'
        with Image.open(source) as im:original=im.convert('RGB').copy()
        tile,score,pillar=make_tile(original)
        coded=pack(tile)
        photos[idx]=coded;samples.append((idx,original,tile,score,pillar))
        print(f'SKU {idx:02d} score={score:.2f} crop={pillar} bytes={len(coded)}',flush=True)
    print('TOTAL_WEBP_BYTES='+str(sum(map(len,photos.values()))),flush=True)
    if args.preview_only:
        sheet=Image.new('RGB',(7*224,5*240),'#fffaf5')
        d=ImageDraw.Draw(sheet)
        for n,(i,original,tile,score,pillar) in enumerate(samples):
            x=(n%7)*224+8;y=(n//7)*240+8
            source=ImageOps.fit(original,(93,93),method=Image.Resampling.LANCZOS)
            target=tile.resize((93,93),Image.Resampling.LANCZOS)
            sheet.paste(source,(x,y+15));sheet.paste(target,(x+107,y+15))
            d.text((x,y),f'#{i:02d} Before',fill=(78,48,31))
            d.text((x+109,y),'After',fill=(78,48,31))
            d.text((x+8,y+116),f'crop={pillar} ({score:.1f})',fill=(78,48,31))
        jpg=io.BytesIO();sheet.save(jpg,format='JPEG',quality=72,optimize=True)
        print('CI_PHOTO_SHEET_BEGIN',flush=True)
        print(base64.b64encode(jpg.getvalue()).decode('ascii'),flush=True)
        print('CI_PHOTO_SHEET_END',flush=True)
        return
    replacement=BEG+'\nconst CI_NORMALIZED_PHOTOS={\n'+'\n'.join(
        f" {i}: 'data:image/webp;base64,{base64.b64encode(raw).decode('ascii')}',"
        for i,raw in photos.items())+'\n};\n'+END
    html=HTML.read_text(encoding='utf8')
    if BEG not in html or END not in html:raise ValueError('HTML marker missing')
    html=re.sub(re.escape(BEG)+r'[\s\S]*?'+re.escape(END),
                lambda _:replacement,html,count=1)
    if "const source=CI_NORMALIZED_PHOTOS[id]||stablePhotoSource(id,resolved?.name);" not in html:
        raise ValueError('photoAttrs must use normalized data')
    if len(html.encode())>=512*1024:raise ValueError(f'OTA exceeds limit: {len(html)}')
    HTML.write_text(html,encoding='utf8')
    print('DEPLOY_HTML_BYTES='+str(len(html.encode())),flush=True)
if __name__=='__main__':main()
