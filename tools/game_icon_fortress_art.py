"""A restrained fortress emblem with one high gate tower and low thick walls.

The 96-unit master reads as fortification first: broad grey stone, one dark
passage and a single projecting red roof. Small beacon fire and one military
standard supply the game identity without hiding the tower. Native SVG only.
"""

FORTRESS_COLORS = {
    "bg_top": "#465354",
    "bg_mid": "#2F3C42",
    "bg_bottom": "#172933",
    "stone_top": "#C7B898",
    "stone_mid": "#A39477",
    "stone_bottom": "#747462",
    "side_top": "#7D826E",
    "side_bottom": "#4B5D58",
    "roof_top": "#C88966",
    "roof_mid": "#9C5B43",
    "roof_bottom": "#643C32",
    "wood": "#564336",
    "wood_lit": "#9E8265",
    "door": "#142A32",
    "reveal": "#6F7B69",
    "inner_wall": "#344C4C",
    "fire_top": "#FFCA74",
    "fire_mid": "#EE9347",
    "fire_bottom": "#B25731",
    "core_top": "#FFEAB2",
    "core_bottom": "#F2BE64",
    "flag_top": "#BC7257",
    "flag_bottom": "#804B3B",
    "copper": "#C7A16C",
    "watch_face": "#B7B193",
    "watch_side": "#7E8C79",
    "lookout": "#2B413E",
    "arch_light": "#B2AF8D",
    "joint": "#6F7560",
    "edge_light": "#D0C4A5",
    "core_light": "#FFE6AD"
}

FORTRESS_DUSK_COLORS = {
    "bg_top": "#25313B",
    "bg_mid": "#151E27",
    "bg_bottom": "#0D141D",
    "stone_top": "#9B9687",
    "stone_mid": "#716F65",
    "stone_bottom": "#484D49",
    "side_top": "#6E7167",
    "side_bottom": "#343D3D",
    "roof_top": "#A3654D",
    "roof_mid": "#794336",
    "roof_bottom": "#492B28",
    "wood": "#493D32",
    "wood_lit": "#85705A",
    "door": "#111C23",
    "reveal": "#4E5550",
    "inner_wall": "#2B383B",
    "fire_top": "#EAAA65",
    "fire_mid": "#CF733F",
    "fire_bottom": "#873F29",
    "core_top": "#F4D797",
    "core_bottom": "#DF9B4E",
    "flag_top": "#A36D51",
    "flag_bottom": "#684637",
    "copper": "#AA8458",
    "watch_face": "#85806F",
    "watch_side": "#555D51",
    "lookout": "#25342F",
    "arch_light": "#687064",
    "joint": "#454E49",
    "edge_light": "#AAA18B",
    "core_light": "#FFE6AD"
}


def build_fortress_crest(colors=None) -> str:
    """Return SVG body; optional partial colour overrides aid native comparison."""
    c = FORTRESS_COLORS | (colors or {})
    return f'''<defs>
<linearGradient id="ff-bg" x1="0" y1="0" x2=".55" y2="1"><stop stop-color="{c['bg_top']}"/><stop offset=".55" stop-color="{c['bg_mid']}"/><stop offset="1" stop-color="{c['bg_bottom']}"/></linearGradient>
<linearGradient id="ff-stone" x1="0" y1="0" x2=".2" y2="1"><stop stop-color="{c['stone_top']}"/><stop offset=".58" stop-color="{c['stone_mid']}"/><stop offset="1" stop-color="{c['stone_bottom']}"/></linearGradient>
<linearGradient id="ff-side" x1="0" y1="0" x2=".75" y2="1"><stop stop-color="{c['side_top']}"/><stop offset="1" stop-color="{c['side_bottom']}"/></linearGradient>
<linearGradient id="ff-roof" x1="0" y1="0" x2=".25" y2="1"><stop stop-color="{c['roof_top']}"/><stop offset=".5" stop-color="{c['roof_mid']}"/><stop offset="1" stop-color="{c['roof_bottom']}"/></linearGradient>
<linearGradient id="ff-fire" x1="0" y1="0" x2=".2" y2="1"><stop stop-color="{c['fire_top']}"/><stop offset=".48" stop-color="{c['fire_mid']}"/><stop offset="1" stop-color="{c['fire_bottom']}"/></linearGradient>
<linearGradient id="ff-core" x1="0" y1="0" x2="0" y2="1"><stop stop-color="{c['core_top']}"/><stop offset="1" stop-color="{c['core_bottom']}"/></linearGradient>
<linearGradient id="ff-flag" x1="0" y1="0" x2="1" y2=".5"><stop stop-color="{c['flag_top']}"/><stop offset="1" stop-color="{c['flag_bottom']}"/></linearGradient>
<clipPath id="ff-door-clip"><path d="M39 85V71Q39 64 49 64Q57 64 57 71V85Z"/></clipPath>
</defs>
<g stroke-linecap="round" stroke-linejoin="round">
<!-- A single subdued edge leaves transparent outer corners; no metallic rim. -->
<rect x="3" y="3" width="90" height="90" rx="18" fill="url(#ff-bg)" stroke="#4B585E" stroke-opacity=".55" stroke-width=".8"/>
<!-- One standard behind the tower; only its point is bronze. -->
<path d="M20 18V62" fill="none" stroke="#5C5548" stroke-width="1.7"/>
<path d="M21 21Q30 18 36 22L34 33Q28 29 21 33Z" fill="url(#ff-flag)" stroke="#483A32" stroke-width=".7"/>
<path d="M22 22Q28 20.5 33.5 22.5M22 23V30" fill="none" stroke="{c['copper']}" stroke-opacity=".5" stroke-width=".55"/>
<path d="M30 21Q28 26 30 30" fill="none" stroke="{c['flag_bottom']}" stroke-opacity=".4" stroke-width=".5"/>
<path d="M21 15L23 18L21 21L19 18Z" fill="{c['copper']}"/>
<!-- Wide fortified wall mass, with a visible right return and low battlements. -->
<path d="M13 61H82V83L76 88H16Z" fill="#071015" opacity=".55" transform="translate(2,1.5)"/>
<path d="M14 61H81V83H14Z" fill="url(#ff-stone)" stroke="#3E4644" stroke-width=".8"/>
<path d="M81 61L87 55V78L81 83Z" fill="url(#ff-side)" stroke="#303B3B" stroke-width=".7"/>
<path d="M12 61V53H19V59H25V53H32V62Z" fill="url(#ff-stone)" stroke="#454B45" stroke-width=".7"/>
<path d="M65 62V53H72V59H78V53H84V61Z" fill="url(#ff-stone)" stroke="#454B45" stroke-width=".7"/>
<path d="M84 54L88 50V59L84 62Z" fill="url(#ff-side)"/>
<path d="M19 53L21 51V58L19 59ZM32 53L34 51V60L32 62ZM72 53L74 51V58L72 59Z" fill="url(#ff-side)" opacity=".75"/>
<path d="M13 54H18M26 54H31M66 54H71M79 54H83" fill="none" stroke="{c['edge_light']}" stroke-width=".65" opacity=".55"/>
<!-- Sparse joints and narrow arrow loops emphasize masonry rather than housing. -->
<path d="M15 70H29M15 78H29M68 70H80M68 78H80M23 62V69M20 71V77M73 62V69M77 71V77" fill="none" stroke="{c['joint']}" stroke-width=".6" opacity=".42"/>
<path d="M19 63H22V68H19ZM73 63H76V68H73Z" fill="#34403E"/>
<!-- Central gatehouse is taller and thicker than its adjoining curtain walls. -->
<path d="M29 58H68V85H29Z" fill="url(#ff-stone)" stroke="#434B46" stroke-width=".8"/>
<path d="M68 58L75 53V80L68 85Z" fill="url(#ff-side)"/>
<path d="M30 60H67V64H30Z" fill="#444D46" opacity=".35"/>
<!-- A shallow arch exposes a substantial jamb and a dark receding passage. -->
<path d="M36 85V71Q36 61 48 61Q60 61 60 71V85Z" fill="{c['reveal']}"/>
<path d="M39 85V71Q39 64 49 64Q57 64 57 71V85Z" fill="{c['door']}"/>
<!-- The left inner jamb recedes right/up, matching the tower's visible right return. -->
<path d="M39 85V71Q39 64 49 64L52 62Q42 62 42 69V85Z" fill="{c['inner_wall']}" clip-path="url(#ff-door-clip)"/>
<path d="M36 71Q36 62 48 61L49 64Q40 64 39 71V84L36 85Z" fill="{c['arch_light']}" opacity=".4"/>
<path d="M39 83H57V85H39Z" fill="#1C292D"/>
<path d="M37 68L39 68.7M47 62L47.4 63.5M56.7 66.6L55.3 67.7" fill="none" stroke="#3E4843" stroke-width=".55" opacity=".55"/>
<path d="M31 77H35M61 78H67M31 68H34M63 68H67M64 74V77" fill="none" stroke="{c['joint']}" stroke-width=".45" opacity=".4"/>
<path d="M45.7 62L46.4 64L50.5 64.2L51.4 62.2Z" fill="{c['stone_top']}" opacity=".4"/>
<!-- One exposed watch-room, broad wood beams and a continuous dark lookout slit. -->
<path d="M31 46H68V59H31Z" fill="{c['watch_face']}" stroke="{c['wood']}" stroke-width=".8"/>
<path d="M68 46L75 41V54L68 59Z" fill="{c['watch_side']}"/>
<path d="M37 49H62V54H37Z" fill="{c['lookout']}"/>
<path d="M69 47.5L72 45.5V50.5L69 52.5Z" fill="{c['lookout']}" opacity=".75"/>
<path d="M32 47V58M67 47V58M32 58H67M45 49V54M54 49V54" fill="none" stroke="{c['wood']}" stroke-width="1.7"/>
<path d="M34 57H65" fill="none" stroke="{c['wood_lit']}" stroke-opacity=".6" stroke-width=".65"/>
<!-- A single broad Han-style projecting roof, without side roofs or temple tiers. -->
<path d="M20 45Q30 44 37 36H62Q68 43 80 43L75 48L70 50H27L21 47Z" fill="{c['wood']}" stroke="#2E3430" stroke-width=".8"/>
<path d="M20 42Q31 42 37 33H61Q68 41 80 40L73 46H28Z" fill="url(#ff-roof)" stroke="#42352F" stroke-width=".9"/>
<path d="M61 33L66 31Q73 38 80 40L73 46Z" fill="{c['roof_bottom']}" opacity=".66"/>
<path d="M29 41Q46 43 69 41M33 37Q46 39 65 37" fill="none" stroke="#B18368" stroke-opacity=".38" stroke-width=".65"/>
<path d="M38 35L34 42M45 35L43 43M53 35L54 43M60 35L64 42" fill="none" stroke="{c['roof_bottom']}" stroke-opacity=".28" stroke-width=".45"/>
<path d="M37 33H61" fill="none" stroke="#A2795D" stroke-width="1.1"/>
<path d="M24 46H73" fill="none" stroke="#6F5844" stroke-width="1"/>
<!-- Compact fire bowl rests on the roof ridge; copper appears only on its lip. -->
<path d="M43 31H60L58 36H45Z" fill="#4D4537" stroke="#2D332C" stroke-width=".75"/>
<path d="M41 31H62V33H41Z" fill="#655139" stroke="#2D332C" stroke-width=".65"/>
<path d="M42 31.5H61" fill="none" stroke="{c['copper']}" stroke-width=".7"/>
<!-- Flame geometry is 85 percent of the former beacon and clears the watch-room. -->
<g transform="translate(8.3,1.1) scale(.85)">
<path d="M43 35C33 30 38 23 44 18C49 14 50 11 50 7C60 14 63 22 60 25C65 23 66 20 66 17C73 27 67 34 60 36C55 39 46 38 43 35Z" fill="url(#ff-fire)" stroke="#67382A" stroke-width=".9"/>
<path d="M47 34C42 29 47 24 51 20C54 17 54 16 54 14C61 21 60 26 57 28C61 28 62 25 63 23C66 31 58 36 53 36C50 36 48 35 47 34Z" fill="url(#ff-core)"/>
<path d="M49 32C47 29 51 26 53 24C53 28 56 29 56 31C56 34 51 35 49 32Z" fill="{c['core_light']}"/>
</g>
<!-- A stone footing, with no bright floor triangle or decorative gold bar. -->
<path d="M12 83H83V86L78 89H18L12 86Z" fill="url(#ff-side)" stroke="#303B3B" stroke-width=".7"/>
<path d="M12.5 83H82L80 84.5H14Z" fill="{c['side_top']}" opacity=".65"/>
<path d="M13 83.5H35M61 83.5H81" fill="none" stroke="#8A8C7A" stroke-opacity=".55" stroke-width=".7"/>
</g>'''
