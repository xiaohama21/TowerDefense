"""Original game emblem: jade enamel, a gold gate and a prominent beacon fire.

The 96-unit master deliberately keeps the doorway and flame as broad shapes.
All shading is native SVG geometry or gradients; there are no bitmap inputs,
filters, lettering or weapon motifs. Gradient IDs are private to this emblem.
"""

DESCRIPTION = "青绿珐琅圆角底、暖金立体城楼与陶红金色烽火；透明四角，多尺寸游戏徽章"


def build_game_ico_frames(crest):
    """Keep the outer corner pixels transparent after small-size resampling."""
    from PIL import Image
    frames = []
    for size in (16, 24, 32, 48, 64, 128, 256):
        frame = crest.convert('RGBA').resize((size, size), Image.Resampling.LANCZOS)
        for corner in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)):
            frame.putpixel(corner, (0, 0, 0, 0))
        frames.append(frame)
    return frames


def build_game_crest() -> str:
    return '''<defs>
<linearGradient id="gc-jade" x1="0" y1="0" x2=".75" y2="1"><stop stop-color="#a2c4a4"/><stop offset=".43" stop-color="#628e73"/><stop offset="1" stop-color="#315b48"/></linearGradient>
<linearGradient id="gc-edge" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#d5d8aa"/><stop offset=".45" stop-color="#9ab68b"/><stop offset="1" stop-color="#264e3e"/></linearGradient>
<linearGradient id="gc-gold" x1="0" y1="0" x2=".32" y2="1"><stop stop-color="#fff0b2"/><stop offset=".42" stop-color="#e9bd68"/><stop offset="1" stop-color="#b27b35"/></linearGradient>
<linearGradient id="gc-gold-side" x1="0" y1="0" x2=".8" y2="1"><stop stop-color="#cb9347"/><stop offset="1" stop-color="#875824"/></linearGradient>
<linearGradient id="gc-bevel" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#fff8cf"/><stop offset=".55" stop-color="#f3d27e"/><stop offset="1" stop-color="#c39750"/></linearGradient>
<linearGradient id="gc-door" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#233e32"/><stop offset="1" stop-color="#547e58"/></linearGradient>
<linearGradient id="gc-fire" x1="0" y1="0" x2=".22" y2="1"><stop stop-color="#f8a762"/><stop offset=".38" stop-color="#df7649"/><stop offset="1" stop-color="#a9482f"/></linearGradient>
<linearGradient id="gc-core" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#fff2b2"/><stop offset=".52" stop-color="#ffd16d"/><stop offset="1" stop-color="#e7a24b"/></linearGradient>
<radialGradient id="gc-sun" cx=".34" cy=".19" r=".82"><stop stop-color="#edf0c1" stop-opacity=".3"/><stop offset="1" stop-color="#edf0c1" stop-opacity="0"/></radialGradient>
</defs>
<g stroke-linecap="round" stroke-linejoin="round">
<!-- Rounded enamel tile, with transparent corners and a narrow metal rim. -->
<rect x="2" y="2" width="92" height="92" rx="20" fill="url(#gc-jade)" stroke="url(#gc-edge)" stroke-width="2"/>
<rect x="5.5" y="5.5" width="85" height="85" rx="17" fill="url(#gc-sun)" stroke="#dce2b1" stroke-opacity=".42" stroke-width=".8"/>
<path d="M11 31V24Q11 11 24 11H39" fill="none" stroke="#eff2c6" stroke-opacity=".32" stroke-width="1.3"/>
<!-- A small solid cast shadow creates depth without blur at small sizes. -->
<path d="M20 44H81L83 50V84H19V48Z" fill="#204134" opacity=".30" transform="translate(1.5,3)"/>
<path d="M17 82H79L84 87H19L13 84Z" fill="#254636" opacity=".32"/>
<!-- Twin gate towers: metal front planes, darker right faces and broad bevels. -->
<path d="M18 44V35H25V41H31V35H38V46L34 51V81H18Z" fill="url(#gc-gold)" stroke="#80532b" stroke-width="1.3"/>
<path d="M34 49L39 46V77L34 81Z" fill="url(#gc-gold-side)"/>
<path d="M62 46V35H69V41H75V35H82V44L77 50V81H62Z" fill="url(#gc-gold)" stroke="#80532b" stroke-width="1.3"/>
<path d="M77 49L82 44V77L77 81Z" fill="url(#gc-gold-side)"/>
<path d="M19 36H24V42H32V36H37M63 36H68V42H76V36H81" fill="none" stroke="url(#gc-bevel)" stroke-width="1.4"/>
<path d="M19 48V77M63 49V77" fill="none" stroke="#fbe0a0" stroke-width="1.1"/>
<path d="M21 53H30M21 67H30M65 53H74M65 67H74" fill="none" stroke="#a97939" stroke-opacity=".48" stroke-width="1.2"/>
<!-- The continuous gold wall has one large dark arch, its defining silhouette. -->
<path d="M31 46H65V82H31Z" fill="url(#gc-gold)" stroke="#81552a" stroke-width="1.2"/>
<path d="M30 46L35 42H62L67 46V51H30Z" fill="url(#gc-gold-side)"/>
<path d="M30 46H67V48H30Z" fill="url(#gc-bevel)"/>
<path d="M36 82V67C36 50 60 50 60 67V82Z" fill="url(#gc-gold-side)"/>
<path d="M39 82V67C39 54 57 54 57 67V82Z" fill="url(#gc-door)" stroke="#94652e" stroke-width=".8"/>
<path d="M37 81V66C37 52 59 52 59 66" fill="none" stroke="#ffe6a4" stroke-width="1.5"/>
<path d="M41 81L48 76L56 81Z" fill="#83a172" opacity=".42"/>
<!-- Stepped sill and a bevel along the tower bases tie the gold volumes together. -->
<path d="M16 79H34V82H62V79H79V83L75 86H20L16 83Z" fill="url(#gc-gold-side)" stroke="#7c512a" stroke-width=".8"/>
<path d="M16 80H34M62 80H79M21 83H75" fill="none" stroke="url(#gc-bevel)" stroke-width="1.5"/>
<!-- Beacon pedestal stays broad; the fire rises above every part of the gate. -->
<path d="M38 42H59L62 47H35Z" fill="url(#gc-gold)" stroke="#875829" stroke-width="1.1"/>
<path d="M38 42H59M37 46H60" fill="none" stroke="url(#gc-bevel)" stroke-width="1.3"/>
<path d="M40 43C28 35 35 25 42 20C47 16 47 12 47 8C57 14 60 22 59 26C64 25 65 20 65 18C74 28 72 36 65 42C59 49 46 48 40 43Z" fill="#6d3928" opacity=".35" transform="translate(1,1.3)"/>
<path d="M39 42C28 34 34 25 41 20C46 16 47 12 47 8C56 13 60 21 58 27C63 25 65 22 65 18C73 28 71 35 64 41C58 47 45 47 39 42Z" fill="url(#gc-fire)" stroke="#8f432e" stroke-width="1.3"/>
<path d="M43 41C37 37 40 31 44 28C48 25 49 21 48 18C56 24 56 30 54 33C58 33 60 30 60 28C64 35 61 40 56 43C51 45 46 44 43 41Z" fill="url(#gc-core)"/>
<path d="M44 39C42 35 46 31 49 29C49 33 53 34 54 38C55 41 51 44 48 43C46 43 44 41 44 39Z" fill="#fff1b6"/>
<path d="M39 30Q39 25 44 22M49 13Q55 17 56 22" fill="none" stroke="#ffcc83" stroke-width="1.2" stroke-opacity=".8"/>
</g>'''
