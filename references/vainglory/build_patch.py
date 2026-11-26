"""Build the reversible resource-only patch from the backed-up 4.13.4 OBB."""
from pathlib import Path
import base64,hashlib,json,re,struct,zipfile
ROOT=Path(__file__).resolve().parent
PAYLOAD=ROOT/'patch'/'Data'
ORIGINALS=ROOT/'restore'/'Data'
TEXT_PATH='7E/7ED4F1146624D2D991A07272993B26C4'
TW_PATH='8E/8E01CA1FDF6F074AC6911296A3833AF6'
def sha(data): return hashlib.sha256(data).hexdigest()
def save(folder,name,data):
    p=folder/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
def rows(data):
    text=base64.b64decode(data,validate=True).decode('utf-8-sig')
    pattern=re.compile(r'^"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";',re.M)
    values=pattern.findall(text)
    assert not pattern.sub('',text).strip(), 'Unparsed localization content'
    assert len(values)==len(dict(values))==7329
    return dict(values)
manifest={'package':'com.superevilmegacorp.game','version_code':147219,'patch_revision':'20261119.3','language_setting':'English','files':[]}
with zipfile.ZipFile(ROOT/'main.147219.original.obb') as z:
    original=z.read(TEXT_PATH); translated=z.read(TW_PATH)
    additions=json.loads((ROOT/'translation-additions.json').read_text(encoding='utf-8'))
    decoded=base64.b64decode(translated).decode('utf-8')
    pattern=re.compile(r'^"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";',re.M)
    decoded=pattern.sub(lambda m: '"'+m.group(1)+'" = "'+additions[m.group(1)]+'";'
                        if m.group(1) in additions else m.group(0),decoded)
    translated=base64.b64encode(decoded.encode('utf-8'))
    original_rows=rows(original); translated_rows=rows(translated)
    assert original_rows.keys()==translated_rows.keys()
    assert len(additions)==312
    assert all(translated_rows[k]==v for k,v in additions.items())
    assert not [k for k,v in original_rows.items() if v and not translated_rows[k]
                and not k.startswith('STORE_ITEM_TEMPLATE_')]
    assert original==(ROOT/'english.strings.phone-backup').read_bytes()
    save(PAYLOAD,TEXT_PATH,translated);save(ORIGINALS,TEXT_PATH,original)
    manifest['files'].append({'path':TEXT_PATH,'kind':'Traditional Chinese strings with completed hero translations in English slot','original_sha256':sha(original),'patched_sha256':sha(translated)})
    fonts=0
    for info in z.infolist():
        if info.file_size!=718: continue
        b=z.read(info)
        if struct.unpack_from('<I',b)[0]!=6: continue
        records=[b[52+111*i:52+111*(i+1)] for i in range(6)]
        if not all(re.fullmatch(rb'[A-F0-9]{32}\x00',rec[14:47]) for rec in records): continue
        for rec in records:
            ref=rec[14:46].decode();assert ref[:2]+'/'+ref in z.namelist()
        # The second record is the first CJK fallback in English mode;
        # the fifth is the game's existing Traditional Chinese font face.
        ranges=[struct.unpack_from('<HH',records[1],47+4*i) for i in range(16)]
        assert (0x4e00,0x9fff) in ranges
        assert (0xff00,0xffef) not in ranges
        patched=bytearray(b)
        dst=52+111
        patched[dst+14:dst+47]=records[4][14:47]
        free=ranges.index((0,0))
        struct.pack_into('<HH',patched,dst+47+4*free,0xff00,0xffef)
        assert len(patched)==len(b)
        # Only a font reference and one unused range are allowed to change.
        allowed=set(range(dst+14,dst+47))|set(range(dst+47+4*free,dst+51+4*free))
        assert all(i in allowed for i,(x,y) in enumerate(zip(b,patched)) if x!=y)
        if records[4][14:46]==b'F9269590C587465466A3658E75913AE4':
            # The bundled Traditional title face itself lacks these seven
            # characters. Route only those to the existing complete CJK face.
            fallback=bytearray(patched[dst:dst+111])
            fallback[14:47]=b'0D9EABC833E2EF3AB23BF310F529DF56\x00'
            fallback[47:111]=bytes(64)
            for i,char in enumerate('丟嫋拋淩眾荊闇'):
                struct.pack_into('<HH',fallback,47+4*i,ord(char),ord(char))
            patched[dst:dst]=fallback
            struct.pack_into('<I',patched,0,7)
            assert len(patched)==829
        save(PAYLOAD,info.filename,patched);save(ORIGINALS,info.filename,b)
        manifest['files'].append({'path':info.filename,'kind':'Traditional Chinese fallback and fullwidth punctuation','original_sha256':sha(b),'patched_sha256':sha(patched)})
        fonts+=1
    assert fonts==34,fonts
    # Avenir shop labels and a large Brandon title are single-face Latin
    # fonts. Keep that Latin face and its metrics, adding the same CJK
    # fallback records already used by the game's composite fonts.
    template_name='Fonts/Brandon-Regular-30.font'
    h=hashlib.md5(template_name.encode()).hexdigest().upper()
    template=(PAYLOAD/(h[:2]+'/'+h)).read_bytes()
    base_size=struct.unpack_from('<H',template,4)[0]
    for font_name in ['Avenir-Medium-24','Avenir-Medium-30','Avenir-Heavy-30','Brandon-Bold-400']:
        h=hashlib.md5(('Fonts/'+font_name+'.font').encode()).hexdigest().upper()
        path=h[:2]+'/'+h
        original=z.read(path)
        assert len(original)==52 and original[18]==1
        size=struct.unpack_from('<H',original,4)[0]
        ratio=size/base_size
        patched=bytearray(template)
        patched[4:18]=original[4:18]
        for i in range(6):
            offset=52+111*i
            if i in (0,5):
                patched[offset:offset+14]=original[4:18]
                patched[offset+14:offset+47]=original[19:52]
            else:
                old_size=struct.unpack_from('<H',patched,offset)[0]
                struct.pack_into('<H',patched,offset,round(old_size*ratio))
                for j in range(3):
                    pos=offset+2+4*j
                    struct.pack_into('<f',patched,pos,struct.unpack_from('<f',patched,pos)[0]*ratio)
        save(PAYLOAD,path,patched);save(ORIGINALS,path,original)
        manifest['files'].append({'path':path,'kind':'CJK fallback for '+font_name,'original_sha256':sha(original),'patched_sha256':sha(patched)})
        fonts+=1
    assert fonts==38
manifest['translation_entries']=7329
manifest['completed_translations']=312
manifest['intentionally_empty_internal_templates']=4
manifest['font_resources']=fonts
(ROOT/'patch-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('Built 7329 Traditional Chinese entries (312 completed) and',fonts,'font resources.')
