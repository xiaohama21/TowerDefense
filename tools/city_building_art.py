"""Original three-quarter city architecture, in a 200 x 175 logical canvas.

The artwork is deterministic SVG.  ``building(key, palette)`` returns its
definitions and transparent body, so callers can compose or rasterize it.
"""

from __future__ import annotations

import random


def _mix(a: str, b: str, t: float) -> str:
    a, b = a.lstrip("#"), b.lstrip("#")
    channels = [round(int(a[i:i + 2], 16) * (1 - t) + int(b[i:i + 2], 16) * t)
                for i in (0, 2, 4)]
    return "#" + "".join(f"{v:02x}" for v in channels)


def _defs(key: str, c: dict) -> str:
    dark, roof, wall, wood, gold = [c[n] for n in ("dark", "roof", "wall", "wood", "gold")]
    stops = {
        "roof": [(0, _mix(roof, "#b2c5a1", .30)), (45, roof), (100, _mix(roof, dark, .50))],
        "roof_side": [(0, _mix(roof, dark, .17)), (100, _mix(roof, dark, .65))],
        "wall": [(0, _mix(wall, "#fff0bd", .24)), (55, wall), (100, _mix(wall, wood, .37))],
        "wall_side": [(0, _mix(wall, wood, .42)), (100, _mix(wall, dark, .43))],
        "wood": [(0, _mix(wood, gold, .30)), (55, wood), (100, _mix(wood, dark, .40))],
        "canvas": [(0, _mix(wall, "#fff3c9", .20)), (45, _mix(wall, roof, .14)), (100, _mix(wall, wood, .47))],
        "canvas_side": [(0, _mix(wall, roof, .28)), (100, _mix(wall, dark, .54))],
        "earth": [(0, _mix(wall, roof, .45)), (100, _mix(wood, dark, .28))],
        "stone": [(0, _mix(wall, "#dfdcc8", .20)), (100, _mix(wall, dark, .27))],
        "cloth": [(0, _mix(gold, "#fff2bb", .13)), (100, _mix(gold, wood, .32))],
        "red": [(0, "#aa6551"), (100, "#683e32")],
        "light": [(0, "#ffe7a0"), (100, "#c99750")],
    }
    result = '<defs>'
    for name, values in stops.items():
        result += f'<linearGradient id="{key}-{name}" x1="0" y1="0" x2=".28" y2="1">'
        result += ''.join(f'<stop offset="{at}%" stop-color="{col}"/>' for at, col in values)
        result += '</linearGradient>'
    result += f'<radialGradient id="{key}-glow"><stop stop-color="#ffd68a" stop-opacity=".34"/><stop offset="1" stop-color="#e2b570" stop-opacity="0"/></radialGradient>'
    result += f'<radialGradient id="{key}-shadow"><stop stop-color="{dark}" stop-opacity=".52"/><stop offset=".58" stop-color="{dark}" stop-opacity=".22"/><stop offset="1" stop-color="{dark}" stop-opacity="0"/></radialGradient>'
    result += f'<pattern id="{key}-grain" width="18" height="16" patternUnits="userSpaceOnUse"><path d="M1 2Q9 4 17 1M0 9Q7 7 18 11M4 15Q11 12 16 15" fill="none" stroke="{gold}" stroke-width=".55" opacity=".19"/></pattern>'
    result += f'<pattern id="{key}-plaster" width="17" height="13" patternUnits="userSpaceOnUse"><path d="M3 3h2M11 8h3M1 11h1" stroke="{wood}" opacity=".16" stroke-width=".65"/></pattern>'
    return result + '</defs>'


def _fill(key: str, name: str) -> str:
    return f'url(#{key}-{name})'


def _path(d: str, fill: str, stroke: str = "none", width: float = 1, extra: str = "") -> str:
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round" {extra}/>'


def _roof(key: str, c: dict, dy: float = 0, scale: float = 1, dx: float = 0) -> str:
    """Hipped slate roof with a thick, curled eave and individually grouped tiles."""
    d, g = c['dark'], c['gold']
    out = f'<g transform="translate({dx},{dy}) scale({scale})">'
    out += _path('M15 77Q68 91 131 103L194 80L192 85L132 110L17 84Z', _mix(c['wood'], d, .46), d, .8)
    out += _path('M16 76Q30 75 40 62L80 31L149 44L132 100Z', _fill(key, 'roof'), d, 1.1)
    out += _path('M149 44L180 69Q185 77 195 79L132 100Z', _fill(key, 'roof_side'), d, 1.1)
    # Tonal variation is confined to individual slate pieces. It breaks up the
    # broad roof plane without making the architecture depend on raster noise.
    def point(t: float, u: float) -> tuple[float, float]:
        ax, ay = 80 - 64 * t, 31 + 45 * t
        bx, by = 149 - 17 * t, 44 + 56 * t
        return ax + (bx - ax) * u, ay + (by - ay) * u
    for row in range(1, 8):
        for tile in range(1, 9):
            if (row * 3 + tile * 5) % 4:
                continue
            t, u = row / 9, tile / 10
            points = [point(t - .07, u - .055), point(t - .07, u + .03),
                      point(t - .01, u + .03), point(t - .01, u - .055)]
            tile_path = 'M' + 'L'.join(f'{x:.2f} {y:.2f}' for x, y in points) + 'Z'
            color = _mix(c['roof'], c['gold'] if tile % 2 else d, .45)
            out += _path(tile_path, color, 'none', extra='opacity=".23"')
    # Rows follow the widening front slope; short vertical strokes are the tile joints.
    for row in range(1, 9):
        t = row / 9
        ax, ay = 80 - 64 * t, 31 + 45 * t
        bx, by = 149 - 17 * t, 44 + 56 * t
        out += _path(f'M{ax:.2f} {ay:.2f}Q{(ax + bx) / 2:.2f} {(ay + by) / 2 + 2:.2f} {bx:.2f} {by:.2f}', 'none', _mix(c['roof'], c['light'], .33), .72)
        for tile in range(1, 10):
            u = (tile + (.35 if row % 2 else 0)) / 10
            x, y = ax + (bx - ax) * u, ay + (by - ay) * u
            out += _path(f'M{x:.2f} {y:.2f}l{-4.2 + u * 3:.2f} 4.2', 'none', _mix(c['roof'], d, .31), .53)
    for row in range(1, 7):
        t = row / 7
        out += _path(f'M{149 + 44 * t:.2f} {44 + 35 * t:.2f}L{149 - 17 * t:.2f} {44 + 56 * t:.2f}', 'none', _mix(c['roof'], c['light'], .17), .62)
    out += _path('M17 76Q62 87 132 101L195 79M15 76L10 72M195 79L199 73', 'none', _mix(c['wood'], g, .32), 2.25)
    out += _path('M80 31L149 44', 'none', _mix(c['roof'], c['light'], .63), 3.5)
    out += _path('M79 28L151 41M80 28L76 24M150 41L154 38', 'none', _mix(c['wood'], g, .40), 1.55)
    # Small carved ridge finials, rather than oversized geometric ornament.
    out += _path('M78 28Q70 27 71 22Q75 23 78 28M150 41Q157 39 156 34Q151 35 150 41', _mix(c['wood'], g, .35), d, .8)
    return out + '</g>'


def _lantern(key: str, c: dict, x: float, y: float, scale: float = 1) -> str:
    out = f'<g transform="translate({x},{y}) scale({scale})">'
    out += f'<ellipse cx="0" cy="5" rx="16" ry="21" fill="{_fill(key, "glow")}"/>'
    out += _path('M0 -9V-4M-4 -4H4L5 6L2 10H-2L-5 6Z', _fill(key, 'light'), c['wood'], .8)
    out += _path('M-4 -4H4M-3 8H3M0 10V14M-2 14H2M0 -3V8', 'none', _mix(c['wood'], c['gold'], .28), .75)
    return out + '</g>'


def _window(key: str, c: dict, x: float, y: float, w: float = 17, h: float = 19, lit: bool = True) -> str:
    out = f'<g transform="translate({x},{y})">'
    out += f'<rect width="{w}" height="{h}" rx=".6" fill="{_fill(key, "light") if lit else c["dark"]}" stroke="{c["wood"]}" stroke-width="2"/>'
    for part in range(1, 4):
        out += _path(f'M{w * part / 4} 1V{h - 1}', 'none', _mix(c['wood'], c['dark'], .35), .8)
    out += _path(f'M1 {h / 2}H{w - 1}M-2 {h + 2}H{w + 2}', 'none', c['wood'], 1.5)
    return out + '</g>'


def _crate(key: str, c: dict, x: float, y: float, scale: float = 1) -> str:
    out = f'<g transform="translate({x},{y}) scale({scale})">'
    out += _path('M0 5L15 0L32 5L16 12Z', _mix(c['wood'], c['gold'], .26), c['dark'], .7)
    out += _path('M0 5L16 12V31L0 23Z', _fill(key, 'wood'), c['dark'], .7)
    out += _path('M16 12L32 5V24L16 31Z', _mix(c['wood'], c['dark'], .20), c['dark'], .7)
    out += _path('M2 8L14 14V28L2 22ZM18 14L30 9V23L18 28Z', 'none', _mix(c['wood'], c['gold'], .4), 1.4)
    out += _path('M2 9L14 27M14 15L2 21M18 15L29 22M30 10L19 27', 'none', _mix(c['wood'], c['gold'], .2), 1.4)
    return out + '</g>'


def _sack(key: str, c: dict, x: float, y: float, scale: float = 1) -> str:
    out = f'<g transform="translate({x},{y}) scale({scale})">'
    out += _path('M-5 0Q-9 5 -10 16Q-12 23 -4 25Q8 29 12 20Q14 9 6 2L5 -1Z', _fill(key, 'canvas'), _mix(c['wood'], c['dark'], .2), .75)
    out += _path('M-5 0L6 1M-3 4Q-8 12 -6 19M6 6Q10 14 8 20M-5 1L-4 -3H5L5 1', 'none', _mix(c['wood'], c['gold'], .1), .65)
    return out + '</g>'


def _jar(key: str, c: dict, x: float, y: float, scale: float = 1, red: bool = False) -> str:
    out = f'<g transform="translate({x},{y}) scale({scale})">'
    out += _path('M-4 0L-5 5Q-11 8 -10 17Q-10 24 0 25Q11 24 10 16Q10 8 5 5L4 0Z', _fill(key, 'red' if red else 'wood'), c['dark'], .8)
    out += f'<ellipse cx="0" cy="0" rx="5" ry="2" fill="{c["dark"]}" stroke="{c["gold"]}" stroke-width=".65"/>'
    out += _path('M-6 8Q-8 14 -6 19M-8 17Q0 22 9 17', 'none', _mix(c['wood'], c['gold'], .5), 1.1)
    return out + '</g>'


def _foundation(key: str, c: dict) -> str:
    out = f'<ellipse cx="106" cy="151" rx="93" ry="20" fill="{_fill(key, "shadow")}"/>'
    out += _path('M26 133L132 153L178 132L72 114Z', _fill(key, 'stone'), _mix(c['wood'], c['dark'], .18), .7)
    out += _path('M26 133V139L132 160V153ZM132 153L178 132V138L132 160Z', _mix(c['wall'], c['dark'], .39), c['dark'], .6)
    out += _path('M28 134L131 155L176 134', 'none', _mix(c['wall'], c['gold'], .26), 1)
    return out


def _house_body(key: str, c: dict, door: str = 'door') -> str:
    out = _foundation(key, c)
    front = 'M33 77L133 97V148L33 128Z'
    side = 'M133 97L174 79V130L133 148Z'
    out += _path(front, _fill(key, 'wall'), c['dark'], 1)
    out += _path(front, _fill(key, 'plaster'))
    out += _path(side, _fill(key, 'wall_side'), c['dark'], 1)
    out += _path('M133 103L174 86M133 144L173 128', 'none', c['wood'], 2)
    # Timbers and sill follow the perspective, with a subtle lit edge.
    out += _path('M34 80L132 99M34 123L132 143M37 79V129M130 98V147M172 81V130', 'none', _fill(key, 'wood'), 4)
    out += _path('M35 81V126M129 100V143M35 82L129 101', 'none', _mix(c['wood'], c['gold'], .38), .65)
    out += '<g transform="translate(38,81) skewY(11.31)">'
    out += _window(key, c, 5, 10, 19, 19)
    if door == 'barn':
        out += '<rect x="34" y="10" width="42" height="44" fill="' + _fill(key, 'wood') + '" stroke="' + c['dark'] + '" stroke-width="1.5"/>'
        out += '<rect x="35" y="11" width="40" height="42" fill="' + _fill(key, 'grain') + '"/>'
        for x in range(37, 77, 6):
            out += _path(f'M{x} 12V53', 'none', _mix(c['wood'], c['dark'], .28), .7)
        out += _path('M35 13L74 51M74 13L35 51M55 12V52M34 22H76M34 45H76', 'none', _mix(c['wood'], c['gold'], .38), 2.3)
        out += '<circle cx="52" cy="33" r="1.4" fill="' + c['dark'] + '"/><circle cx="58" cy="33" r="1.4" fill="' + c['dark'] + '"/>'
    elif door == 'open':
        out += '<rect x="34" y="11" width="47" height="43" fill="' + c['dark'] + '" stroke="' + c['wood'] + '" stroke-width="2"/>'
        out += _path('M35 11V54L45 51V12ZM81 11V54L71 51V12Z', _fill(key, 'wood'), c['dark'], .6)
    else:
        out += _path('M35 54V16Q46 5 58 16V54Z', c['dark'], c['wood'], 2.5)
        out += _path('M36 54V18L44 15V51Z', _fill(key, 'wood'), c['dark'], .8)
        out += _path('M58 17V54L52 52V15Z', _fill(key, 'wood'), c['dark'], .8)
        out += _window(key, c, 71, 11, 16, 20)
    out += '</g>'
    # Step stones catch the sunset at their front lip.
    out += _path('M68 139L94 144L90 148L64 143ZM64 143L90 148L86 153L59 148Z', _fill(key, 'stone'), _mix(c['wood'], c['dark'], .18), .65)
    out += _path('M59 148L86 153', 'none', _mix(c['wall'], c['gold'], .36), 1)
    return out


def _command(key: str, c: dict) -> str:
    """Wide ceremonial command pavilion with two peaks, never a small tent."""
    d, g, w = c['dark'], c['gold'], c['wood']
    out = f'<ellipse cx="102" cy="149" rx="96" ry="17" fill="{_fill(key,"shadow")}"/>'
    out += _path('M18 129L112 155L185 132L82 110Z', _fill(key,'earth'), w, .8)
    out += _path('M18 98L116 119L182 98L181 139L114 158L18 137Z', _fill(key,'canvas'), d, 1)
    out += _path('M116 119L182 98L181 139L114 158Z', _fill(key,'canvas_side'), d, 1)
    out += _path('M12 99L67 43L95 66L134 30L188 99L116 122Z', _fill(key,'canvas'), d, 1.2)
    out += _path('M67 43L95 66L116 122L12 99Z', _mix(c['wall'],g,.17), d, .8)
    out += _path('M134 30L188 99L116 122L95 66Z', _fill(key,'canvas_side'), d, .8)
    out += _path('M67 43L54 108M79 53L84 114M134 30L154 110M120 46L121 120', 'none', _mix(c['wall'],'#fff5d4',.4), 1.6)
    out += _path('M12 99Q62 117 116 122L188 99', 'none', _mix(w,g,.32), 3)
    out += _path('M13 100L116 121L187 98L186 106L116 129L14 108Z', _fill(key,'cloth'), d, .6)
    for x in range(24,112,12):
        y=108+(x-24)*.20
        out += _path(f'M{x} {y:.1f}l3 8l3 -7Z', _mix(g,w,.12), d, .35)
    # Deep central opening, two tied curtains and a small command dais.
    out += _path('M67 118L108 127L108 157L66 146Z', d, w, 1)
    out += _path('M67 118L80 121Q80 136 70 145L66 146Z', _fill(key,'canvas'), w, .75)
    out += _path('M109 127L96 124Q97 139 106 152L109 157Z', _fill(key,'canvas'), w, .75)
    out += _path('M70 139L76 138M101 145L106 146', 'none',g,2)
    out += _path('M76 145L98 150L92 156L72 151Z', _fill(key,'wood'), w, .7)
    out += _path('M68 150L105 160L97 164L62 154Z', _fill(key,'stone'), w, .65)
    for x,y in [(27,115),(44,119),(132,128),(150,122),(169,114)]:
        out += _path(f'M{x} {y}l1 19M{x+4} {y+1}l1 18', 'none', _mix(w,c['wall'],.45), .7)
    # Independent standards emphasize the command entrance and the double ridge.
    for x,y,red in [(67,43,False),(134,30,False),(24,150,True),(171,147,True)]:
        top=y-(31 if red else 26)
        out += _path(f'M{x} {y}V{top}', 'none',w,2)
        out += _path(f'M{x+1} {top+2}Q{x+15} {top} {x+25} {top+6}L{x+21} {top+18}Q{x+10} {top+13} {x+1} {top+16}Z', _fill(key,'red' if red else 'cloth'), d,.65)
        out += _path(f'M{x+4} {top+5}L{x+21} {top+8}M{x+5} {top+13}L{x+18} {top+15}', 'none',g,.65)
    out += _lantern(key,c,42,128,.65) + _lantern(key,c,146,133,.65)
    out += _path('M11 107L4 144M188 108L195 145', 'none',w,.9)
    out += _path('M3 141V148M195 142V149', 'none',d,2)
    return out


def _tech(key: str, c: dict) -> str:
    """Low open lean-to; its large campaign sand table is the main object."""
    d,w,g=c['dark'],c['wood'],c['gold']
    out=f'<ellipse cx="109" cy="151" rx="91" ry="17" fill="{_fill(key,"shadow")}"/>'
    out+=_path('M20 132L108 157L187 130L88 109Z',_fill(key,'earth'),w,.7)
    # Rear lattice and open canopy, not walls or a peaked command tent.
    out+=_path('M54 62L168 81V123L54 103Z',_mix(c['roof'],c['wall'],.35),w,.8)
    for x in range(61,166,13):
        y=62+(x-54)*.167
        out+=_path(f'M{x} {y:.1f}v34', 'none',w,1)
    out+=_path('M56 77L166 96M56 92L166 111', 'none',w,1.2)
    out+=_path('M13 70L59 45L177 63L126 90Z',_mix(c['roof'],c['wall'],.60),d,1)
    out+=_path('M13 70L126 90L177 63V69L127 97L13 77Z',_fill(key,'canvas_side'),d,.65)
    out+=_path('M15 72L126 92L175 65', 'none',_mix(c['wall'],g,.45),1.4)
    for x in range(33,122,16):
        out+=_path(f'M{x} {70+(x-13)*.18:.1f}L{x+44} {46+(x-13)*.15:.1f}', 'none',_mix(c['roof'],c['wall'],.32),.8)
    out+=_path('M17 75V130M127 94V140M173 67V119M58 49V109', 'none',_fill(key,'wood'),3.3)
    # Broad tabletop with raised edge, river, hills and flags.
    out+=_path('M31 129L86 102L182 123L121 157Z',_fill(key,'wood'),d,1.1)
    out+=_path('M31 129V139L121 165V157ZM121 157L182 123V133L121 165Z',_mix(w,d,.15),d,.7)
    out+=_path('M39 128L87 108L173 125L120 150Z',_mix(c['wall'],c['ground'],.25),w,1)
    out+=_path('M50 128Q73 120 88 128T116 131Q139 123 161 128', 'none','#77a5a2',2.5)
    out+=_path('M56 123l8 -8l9 11l-12 3ZM109 125l7 -10l11 13l-13 4ZM142 131l9 -8l9 10l-14 3Z',_mix(c['roof'],c['ground'],.3),w,.65)
    for x,y in [(79,128),(102,141),(145,129)]:
        out+=_path(f'M{x} {y}V{y-17}', 'none',w,.9)
        out+=_path(f'M{x} {y-17}l10 3l-10 5Z',_fill(key,'red'),d,.45)
    out+=_path('M39 138V155M120 161V170M174 134V151', 'none',_fill(key,'wood'),3)
    out+=_path('M17 135L34 137L30 145L14 143Z',_fill(key,'canvas'),w,.7)
    out+=_path('M18 139L28 140M19 142L26 143', 'none',w,.6)
    out+=_lantern(key,c,165,92,.55)
    out+=_path('M12 146L21 148L18 156L8 153Z',_fill(key,'wood'),d,.6)
    return out


def _gate(key: str, c: dict) -> str:
    d, w, g = c['dark'], c['wood'], c['gold']
    out = f'<ellipse cx="108" cy="154" rx="94" ry="19" fill="{_fill(key, "shadow")}"/>'
    out += _path('M20 136L134 160L185 136L69 113Z', _fill(key, 'stone'), d, .8)
    front = 'M26 79L136 100V154L26 133Z'
    out += _path(front, _fill(key, 'stone'), d, 1)
    out += _path('M136 100L182 79V136L136 154Z', _fill(key, 'wall_side'), d, 1)
    # Dressed blockwork across the earth-filled defensive wall.
    out += '<g transform="translate(27,80) skewY(10.81)">'
    for y in [8, 20, 32, 44]:
        out += _path(f'M0 {y}H108', 'none', _mix(w, c['wall'], .30), .6)
        for x in range(8 + (12 if y % 24 else 0), 108, 24):
            out += _path(f'M{x} {y}v12', 'none', _mix(w, c['wall'], .30), .55)
    out += _path('M38 54V25Q55 4 76 25V54Z', d, _mix(w, g, .25), 4)
    out += _path('M40 54V28Q55 12 74 28', 'none', _mix(c['wall'], g, .32), 1)
    out += _path('M46 52L62 44L72 46L72 53Z', _mix(c['wall'], w, .40))
    out += _path('M43 52V30L49 26V50ZM74 28V53L68 50V25Z', _fill(key, 'wood'), d, .7)
    out += _path('M44 32V46M46 31V47M69 30V46M71 31V48', 'none', _mix(w, g, .42), .65)
    out += '</g>'
    out += _path('M136 109L182 88M136 124L182 103M136 139L182 118', 'none', _mix(w, c['wall'], .10), .65)
    for x in [26, 47, 118, 136]:
        yy = 79 + (x - 26) * .19
        out += _path(f'M{x} {yy}V{yy + 53}', 'none', _fill(key, 'wood'), 4)
    # Flanking gatehouses: different depths make the entry a real architectural volume.
    out += _path('M31 49L67 56V91L31 84ZM67 56L83 48V83L67 91Z', _fill(key, 'wall'), d, .8)
    out += _window(key, c, 43, 58, 14, 17, False)
    out += _roof(key, c, 16, .42, 17)
    out += _path('M132 64L165 70V108L132 101ZM165 70L182 62V99L165 108Z', _fill(key, 'wall_side'), d, .8)
    out += _window(key, c, 144, 75, 13, 17, False)
    out += _roof(key, c, 32, .39, 122)
    # Covered central lintel and a small copper studded plaque without words.
    out += _path('M63 87L111 96L136 85L88 76Z', _fill(key, 'roof'), d, 1)
    out += _path('M62 87L111 97L138 85', 'none', _mix(c['roof'], c['light'], .5), 2)
    out += _path('M72 95L102 101V109L72 103Z', _fill(key, 'wood'), d, .6)
    for x in [76, 98]:
        out += f'<circle cx="{x}" cy="{98 + (x - 76) * .2:.1f}" r="1" fill="{g}"/>'
    out += _path('M38 46V12M158 61V26', 'none', w, 1.5)
    out += _path('M39 13L60 16L57 30L39 27ZM159 27L179 31L174 44L159 41Z', _fill(key, 'red'), d, .7)
    out += _path('M40 15L57 17M160 29L175 32', 'none', g, .65)
    out += _lantern(key, c, 43, 114, .83) + _lantern(key, c, 153, 137, .83)
    out += _path('M18 136L28 131L31 143L19 147ZM173 141L185 136L186 144L174 149Z', _fill(key, 'stone'), d, .6)
    return out


def _training(key: str, c: dict) -> str:
    d, w, g = c['dark'], c['wood'], c['gold']
    out = f'<ellipse cx="107" cy="152" rx="94" ry="19" fill="{_fill(key, "shadow")}"/>'
    out += _path('M13 126L84 88L188 114L113 158Z', _fill(key, 'earth'), d, .9)
    out += _path('M13 126V133L113 166V158ZM113 158L188 114V121L113 166Z', _mix(w, d, .19), d, .7)
    out += _path('M20 126L85 94L177 116L112 151Z', _mix(c['wall'], w, .25), _mix(w, g, .12), .75)
    for i in range(1, 7):
        out += _path(f'M{22 + i * 11} {124 - i * 5.1:.1f}L{112 + i * 10} {148 - i * 5.1:.1f}', 'none', _mix(c['wall'], w, .5), .6)
    # A tiled shelter over the weapon racks at the rear of the practice yard.
    out += _path('M31 45V113M70 55V127M104 44V110M31 73L70 82L104 68', 'none', _fill(key, 'wood'), 4)
    out += _roof(key, c, 6, .53, 11)
    out += _path('M34 63L71 70L97 59M34 93L70 103', 'none', w, 2.3)
    for x, y in [(39, 58), (48, 61), (57, 63), (66, 66)]:
        out += _path(f'M{x} {y}L{x - 3} {y + 49}', 'none', _mix(w, g, .36), 1.1)
        out += _path(f'M{x} {y - 10}l-3 10h5Z', _mix(c['wall'], '#c9d6cb', .5), d, .6)
    out += _path('M42 83L63 89M42 86L62 92', 'none', d, 1.1)
    # Bow, scabbards, and a straw training dummy.
    out += _path('M80 65Q95 89 78 115M80 65L78 115', 'none', _mix(w, g, .38), 1.3)
    out += _path('M88 86V135M75 103L101 108', 'none', w, 3)
    out += f'<ellipse cx="88" cy="86" rx="8" ry="10" fill="{_fill(key, "canvas")}" stroke="{w}" stroke-width=".8"/>'
    out += _path('M82 99L92 102L95 121L80 118Z', _fill(key, 'canvas'), w, .8)
    out += _path('M83 102l-2 13M87 102l-1 15M91 104v15', 'none', _mix(w, g, .38), .7)
    for x, y, s in [(129, 77, 1), (162, 99, .9)]:
        out += f'<g transform="translate({x},{y}) scale({s})">'
        out += _path('M0 12V49M0 41L-9 49M0 41L10 50', 'none', _fill(key, 'wood'), 2.8)
        out += f'<ellipse rx="16" ry="20" fill="{_fill(key, "canvas")}" stroke="{d}" stroke-width="1.1"/>'
        for rx, ry, color in [(11, 14, c['roof']), (6, 8, g), (2, 3, '#8a5441')]:
            out += f'<ellipse rx="{rx}" ry="{ry}" fill="none" stroke="{color}" stroke-width="1.7"/>'
        out += _path('M-13 -10L-9 -7M11 12L8 9', 'none', w, .6)
        out += '</g>'
    out += _path('M19 135L47 144M20 131V145M45 140V152M142 143L173 126M143 138V151M172 121V136', 'none', _fill(key, 'wood'), 2.8)
    out += _lantern(key, c, 23, 119, .75)
    out += _crate(key, c, 151, 132, .63)
    return out


def _stable(key: str, c: dict) -> str:
    """Open animal enclosure with a side shelter, rather than a horse stable."""
    d,w,g=c['dark'],c['wood'],c['gold']
    out=f'<ellipse cx="109" cy="150" rx="92" ry="18" fill="{_fill(key,"shadow")}"/>'
    out+=_path('M17 119L85 84L189 115L114 157Z',_mix(c['ground'],c['wall'],.25),w,.8)
    out+=_path('M18 120L113 152L187 114', 'none',_mix(c['wall'],g,.28),1.3)
    # Three-sided modest shade shelter only occupies the left third of the yard.
    out+=_path('M19 86L64 97V122L19 111Z',_fill(key,'wood'),d,.7)
    out+=_path('M12 85L34 51L78 62L66 99Z',_mix(c['wall'],c['roof'],.14),d,1)
    out+=_path('M34 51L87 36L105 58L78 62Z',_mix(c['wall'],g,.3),d,.8)
    out+=_path('M12 85L66 99L96 81M16 87V124M65 98V139M95 80V116', 'none',_fill(key,'wood'),3.2)
    for x in [26,38,49]:
        out+=_path(f'M{x} {81+(x-16)*.25:.1f}L{x+18} {54+(x-16)*.20:.1f}', 'none',_mix(c['wall'],w,.4),.65)
    # Back rails are drawn behind the animals so their outlines remain visible.
    out+=_path('M90 83L187 114M90 94L187 126', 'none',_fill(key,'wood'),3.2)
    for x,y in [(91,83),(121,92),(155,102),(186,113)]:
        out+=_path(f'M{x} {y-8}V{y+26}', 'none',w,3)
        out+=_path(f'M{x-1} {y-7}V{y+23}', 'none',_mix(w,g,.3),.65)
    # Tawny stag: visible neck, muzzle, antlers, four legs and short tail.
    animal=_mix(c['wood'],c['gold'],.40)
    out+=_path('M88 111Q98 99 123 107L137 93L140 78L147 79L150 94L144 105L133 119L106 125L94 120Z',animal,d,.85)
    out+=_path('M138 79L145 69L151 71L160 77L157 83L146 85Z',_mix(animal,c['wall'],.22),d,.75)
    out+=_path('M145 71L141 62L149 67M151 72L157 64L155 74',animal,d,.7)
    out+=_path('M144 70L140 57L135 54M141 61L146 53L144 48M152 72L155 55L161 50M155 61L149 53', 'none',_mix(w,d,.25),1.2)
    out+=_path('M98 119L96 138L100 142M109 123L108 143L113 145M130 118L134 139L139 140M122 121L121 139L125 141', 'none',animal,3)
    out+=_path('M98 140L103 141M109 144L114 145M134 140L140 141', 'none',d,1.3)
    out+=_path('M90 113L83 107L91 107',animal,d,.65)
    out+='<circle cx="151" cy="77" r="1.2" fill="'+d+'"/>'
    out+=_path('M106 109Q121 109 128 113M146 81L151 82', 'none',_mix(animal,c['wall'],.45),.9)
    # Small crouching boar, a distinctly different low rounded silhouette.
    out+=_path('M40 125Q36 112 48 111Q66 109 76 121L85 123L85 129L75 132L68 138L48 135Z',_mix(w,d,.28),d,.8)
    out+=_path('M70 117L72 108L78 119M50 115L47 108L57 114',_mix(w,d,.2),d,.65)
    out+=_path('M46 132V142M60 135V146M73 132V141M39 124Q31 121 36 116', 'none',_mix(w,d,.25),2)
    out+='<circle cx="77" cy="124" r="1" fill="'+c['wall']+'"/>'
    out+=_path('M52 116Q63 115 67 120', 'none',_mix(w,c['wall'],.22),1)
    # Front fence frames legs without covering heads or torsos.
    for x,y in [(18,119),(46,129),(77,140),(112,151),(150,133),(188,113)]:
        out+=_path(f'M{x} {y+9}V{y-4}L{x+2} {y-7}L{x+4} {y-3}V{y+10}Z',_fill(key,'wood'),d,.65)
    out+=_path('M20 124L112 155L190 118M20 132L112 163L190 126', 'none',_fill(key,'wood'),3.2)
    out+=_path('M21 123L112 154L189 117', 'none',_mix(w,g,.45),.7)
    out+=_path('M151 135L174 127L179 138L157 146Z',_fill(key,'wood'),d,.75)
    out+=_path('M155 136L171 131L174 136L158 141Z',_mix(c['gold'],c['ground'],.25),w,.6)
    out+=_jar(key,c,17,136,.65)
    return out



def _shop(key: str, c: dict) -> str:
    """Three colourful market stalls, with no dwelling hidden underneath."""
    d,w,g=c['dark'],c['wood'],c['gold']
    out=f'<ellipse cx="106" cy="150" rx="96" ry="18" fill="{_fill(key,"shadow")}"/>'
    out+=_path('M13 127L90 93L192 126L108 159Z',_fill(key,'earth'),w,.75)
    def stall(x,y,scale,cloth,accent):
        body=f'<g transform="translate({x},{y}) scale({scale})">'
        body+=_path('M9 20L70 34L82 27V74L18 58Z',_fill(key,'wood'),d,.75)
        body+=_path('M4 19L27 0L90 13L69 38Z',cloth,d,1)
        for i in range(0,6,2):
            xx=4+i*10.5
            body+=_path(f'M{xx} {19+i*3.0}L{xx+11} {22+i*3.0}L{xx+32} {3+i*2.2}L{xx+21} {i*2.2}Z',accent,'none')
        body+=_path('M4 19Q9 29 15 23Q21 34 27 27Q33 36 39 30Q45 41 51 33Q58 45 69 38L69 43L4 25Z',cloth,w,.65)
        body+=_path('M5 23V79M69 42V97M87 17V73', 'none',_fill(key,'wood'),3)
        body+=_path('M5 77L67 92L82 83L19 67Z',_fill(key,'wood'),d,.8)
        body+=_path('M5 77V86L67 102V92ZM67 92L82 83V93L67 102Z',_mix(w,d,.12),d,.7)
        body+=_path('M8 82L65 96', 'none',_mix(w,g,.4),.65)
        for i,col in enumerate([c['roof'],c['wall'],accent]):
            px=15+i*16;py=69+i*3.7
            body+=_path(f'M{px} {py}l3 -8l11 3l-2 8Z',col,d,.55)
            body+=f'<ellipse cx="{px+2}" cy="{py-4}" rx="2.5" ry="4" fill="{_mix(col,c["wall"],.2)}" stroke="{d}" stroke-width=".5"/>'
        body+=_path('M47 58V73M39 61L55 64M41 62L38 70M53 64L57 74', 'none',w,.9)
        body+=_path('M33 70Q39 75 44 72M52 74Q57 78 63 75', 'none',g,1)
        body+=_lantern(key,c,76,38,.6)
        return body+'</g>'
    # Staggered depths and different fabrics create three large readable masses.
    out+=stall(102,33,.88,_mix(c['roof'],c['wall'],.48),c['roof'])
    out+=stall(54,67,.82,'#b6c6b6','#638b87')
    out+=stall(4,57,1.04,'#efdcab','#b66d50')
    out+=_crate(key,c,141,133,.88)+_crate(key,c,169,124,.7)
    out+=_sack(key,c,185,139,.65)
    out+=_path('M15 68V26M16 29L36 34L32 52L16 47Z',_fill(key,'red'),w,.75)
    out+=_path('M21 34L31 37M21 43L29 45', 'none',g,.8)
    return out



def _inventory(key: str, c: dict) -> str:
    """Long narrow boarded warehouse, oversized doors and a loaded cart."""
    d,w,g=c['dark'],c['wood'],c['gold']
    out=f'<ellipse cx="107" cy="150" rx="94" ry="18" fill="{_fill(key,"shadow")}"/>'
    out+=_path('M20 126L76 153L171 120L108 99Z',_fill(key,'stone'),w,.75)
    out+=_path('M25 79L78 94V146L25 130Z',_fill(key,'wood'),d,.9)
    out+=_path('M78 94L164 65V119L78 146Z',_mix(w,c['wall'],.16),d,.9)
    # Long straight gable ridge and two roof planes replace the shared hip roof.
    out+=_path('M19 80L47 39L131 15L103 57Z',_mix(c['roof'],c['wall'],.22),d,1)
    out+=_path('M47 39L78 79L165 52L131 15Z',_fill(key,'roof'),d,1)
    out+=_path('M19 80L78 97L171 64L165 52L78 89Z',_mix(c['roof'],d,.2),d,.8)
    out+=_path('M47 39L131 15M19 80L78 96L169 64', 'none',_mix(w,g,.36),2)
    for i in range(1,7):
        t=i/7
        out+=_path(f'M{47+31*t:.1f} {39+40*t:.1f}L{131+34*t:.1f} {15+37*t:.1f}', 'none',_mix(c['roof'],c['light'],.28),.8)
    for i in range(1,8):
        x=78+i*10.3;y=94-i*3.45
        out+=_path(f'M{x:.1f} {y:.1f}V{146-i*3.3:.1f}', 'none',_mix(w,d,.22),.9)
    out+=_path('M82 108L159 82M82 128L160 102M82 140L160 117', 'none',_mix(w,g,.24),2.5)
    out+=_path('M89 109L115 119M115 98L88 130M127 98L151 106M151 84L128 120', 'none',_mix(w,d,.17),2)
    # Full-height paired doors cover almost the entire short front face.
    out+=_path('M30 89L70 100V144L30 132Z',_mix(w,d,.20),d,1.3)
    for i in range(1,7):
        x=30+i*6.3
        out+=_path(f'M{x:.1f} {89+i*1.6:.1f}V{132+i*1.8:.1f}', 'none',_mix(w,g,.25),.7)
    out+=_path('M31 93L68 140M68 101L32 129M50 96V137M30 108L70 119M30 124L70 135', 'none',_mix(w,g,.37),2.2)
    out+='<circle cx="47" cy="118" r="1.3" fill="'+g+'"/><circle cx="54" cy="120" r="1.3" fill="'+g+'"/>'
    out+=_path('M25 80V132M78 95V144M162 67V119', 'none',_fill(key,'wood'),3.2)
    out+=_path('M32 138L68 149L60 154L25 143Z',_fill(key,'stone'),w,.6)
    # The cart is a large foreground identity cue with a visible axle and wheels.
    out+=_crate(key,c,114,120,.73)+_sack(key,c,144,123,.83)+_sack(key,c,164,122,.69)
    out+=_path('M103 137L148 147L184 130V139L150 157L104 145Z',_fill(key,'wood'),d,.8)
    out+=_path('M107 135L150 145L181 131M104 139L148 150L182 136', 'none',_mix(w,g,.4),2.4)
    out+=_path('M108 141L83 157M116 145L93 163M112 145L169 145', 'none',_fill(key,'wood'),2.5)
    for x,y,r in [(124,154,11),(169,144,9)]:
        out+=f'<ellipse cx="{x}" cy="{y}" rx="{r*.7}" ry="{r}" fill="{_mix(w,d,.25)}" stroke="{d}" stroke-width="1.2"/>'
        out+=f'<ellipse cx="{x}" cy="{y}" rx="{r*.46}" ry="{r*.72}" fill="none" stroke="{_mix(w,g,.45)}" stroke-width="1"/>'
        out+=_path(f'M{x} {y-r+2}V{y+r-2}M{x-r*.5} {y}H{x+r*.5}', 'none',_mix(w,g,.45),1)
    out+=_sack(key,c,14,129,.8)+_crate(key,c,4,141,.6)
    out+=_lantern(key,c,70,109,.65)
    return out



def _tavern(key: str, c: dict) -> str:
    """Tall narrow two-storey wine house with steep red roof and wine banner."""
    d,w,g=c['dark'],c['wood'],c['gold']
    out=f'<ellipse cx="107" cy="150" rx="78" ry="17" fill="{_fill(key,"shadow")}"/>'
    out+=_path('M45 129L126 158L164 138L81 111Z',_fill(key,'stone'),w,.7)
    out+=_path('M53 75L122 96V152L53 134Z',_fill(key,'wall'),d,.9)
    out+=_path('M122 96L159 75V135L122 152Z',_fill(key,'wall_side'),d,.9)
    out+=_path('M53 79L122 98M53 129L122 148M55 77V135M120 97V150M156 77V134', 'none',_fill(key,'wood'),3.3)
    # Lower wine-house awning, red canvas with a carved balcony above it.
    out+=_path('M42 103L123 122L166 100L85 84Z','#b56b50',d,.8)
    out+=_path('M42 103L123 122L166 100V105L123 129L42 110Z','#8f533f',d,.65)
    out+=_path('M42 103L123 122L166 100', 'none',_mix(g,c['wall'],.3),1.7)
    for i in range(1,9):
        x=42+i*8.9;y=103+i*2.1
        out+=_path(f'M{x:.1f} {y:.1f}l28 -21', 'none',_mix('#b56b50',g,.32),.65)
    # Upper storey is slender and exposed; its tall roof is unlike camp warehouses.
    out+=_path('M66 50L126 68V100L66 85Z',_fill(key,'wall'),d,.8)
    out+=_path('M126 68L153 51V88L126 100Z',_fill(key,'wall_side'),d,.8)
    out+=_path('M67 51V87M125 68V100M151 53V88M66 84L125 100L153 86', 'none',_fill(key,'wood'),2.8)
    out+='<g transform="translate(72,55) skewY(15)">'
    out+=_window(key,c,1,9,16,18)+_window(key,c,29,9,16,18)
    out+='</g>'
    out+=_path('M49 50L90 12L143 29L127 77Z','#bd7253',d,1)
    out+=_path('M143 29L174 59L127 77Z','#945640',d,1)
    for i in range(1,7):
        t=i/7
        out+=_path(f'M{90-41*t:.1f} {12+38*t:.1f}L{143-16*t:.1f} {29+48*t:.1f}', 'none',_mix('#bd7253',g,.35),.8)
    out+=_path('M49 50L127 78L174 59M90 12L143 29', 'none',_mix(w,g,.4),2.2)
    out+=_path('M89 10L144 26M88 10L83 6M145 26L150 23', 'none',_mix('#945640',g,.35),1.6)
    out+=_path('M66 86L125 103L154 88M66 91L125 108L154 93', 'none',_fill(key,'wood'),2.5)
    for i in range(6):
        x=69+i*9
        out+=_path(f'M{x} {88+i*2.8:.1f}v8', 'none',w,1)
    # Open lower doorway, wine jars and a large hanging wine sign.
    out+=_path('M80 145V122L99 126V151Z',d,w,1.3)
    out+=_path('M80 121L87 123V148L80 145ZM99 126L104 127V153L99 151Z',_fill(key,'wood'),d,.6)
    out+=_path('M149 125V57L183 68', 'none',_fill(key,'wood'),2.7)
    out+=_path('M164 67L184 74V110L164 104Z',_fill(key,'red'),d,.8)
    out+=_path('M168 74L179 77M168 99L179 103', 'none',g,.8)
    out+=_path('M173 79v5q-6 2 -5 7q1 7 6 7q6 -1 5 -6q-1 -4 -4 -5v-7Z',_mix(g,c['wall'],.30),w,.65)
    out+=_jar(key,c,43,134,.94,True)+_jar(key,c,60,147,.70,True)+_jar(key,c,154,137,.86,True)
    out+=_path('M14 140L39 148L55 141L30 134Z',_fill(key,'wood'),d,.7)
    out+=_path('M17 142V154M39 149V160M52 143V151', 'none',w,2)
    out+=_lantern(key,c,65,119,.77)+_lantern(key,c,126,130,.67)
    return out



def _library(key: str, c: dict) -> str:
    d, w, g = c['dark'], c['wood'], c['gold']
    out = _house_body(key, c) + _roof(key, c, 13)
    # A raised upper pavilion turns the archive into the tallest domestic silhouette.
    out += _path('M59 45L122 58V85L59 73Z', _fill(key, 'wall'), d, .8)
    out += _path('M122 58L149 46V74L122 85Z', _fill(key, 'wall_side'), d, .8)
    out += _path('M61 46V73M120 59V84M146 48V73M59 71L122 83L149 72', 'none', _fill(key, 'wood'), 2.5)
    out += '<g transform="translate(64,47) skewY(11.31)">'
    out += _window(key, c, 3, 7, 18, 14) + _window(key, c, 31, 7, 18, 14)
    out += '</g>'
    out += _roof(key, c, 0, .66, 40)
    out += _path('M61 80L120 92L147 80M61 84L120 96L147 84', 'none', _mix(w, g, .38), 1.8)
    for i in range(7):
        x = 63 + i * 8.5
        out += _path(f'M{x:.1f} {81 + i * 1.7:.1f}v5', 'none', w, 1)
    # Open reading table and bundles of scrolls, in the same perspective as the steps.
    out += _path('M12 143L35 133L67 141L45 153Z', _fill(key, 'wood'), d, .8)
    out += _path('M15 144V157M44 154V166M63 143V154', 'none', w, 2)
    out += _path('M22 141L33 137L45 143L43 149L34 145L24 147Z', _fill(key, 'canvas'), w, .6)
    out += _path('M33 138L34 145M26 142L30 143M37 143L41 145', 'none', w, .6)
    for i in range(3):
        x, y = 153 + i * 7, 138 + i * 1.5
        out += _path(f'M{x} {y}l1 -16l5 1v16Z', _fill(key, 'canvas'), w, .65)
        out += _path(f'M{x} {y - 8}l6 1', 'none', _mix(g, w, .35), 1)
    out += _path('M151 141L176 146L175 152L150 147Z', _fill(key, 'wood'), d, .6)
    out += _lantern(key, c, 129, 127, .84)
    return out


_DRAWERS = {
    'map': _gate,
    'command': _command,
    'tech': _tech,
    'develop': _training,
    'tavern': _tavern,
    'stable': _stable,
    'shop': _shop,
    'inventory': _inventory,
    'encyclopedia': _library,
}


def building(key: str, c: dict) -> str:
    """Return a distinct, transparent, detailed city building SVG body.

    Prefixing IDs with the building name makes all nine bodies safe to compose
    into one document.  No fonts, text, external images, or filters are used.
    """
    if key not in _DRAWERS:
        raise ValueError(f'Unknown city building: {key}')
    result = _defs(key, c)
    result += '<g transform="translate(8,0) scale(.92)" stroke-linejoin="round" stroke-linecap="round">'
    result += _DRAWERS[key](key, c)
    # Hand placed chips and tiny earth flecks give the foundations a worn edge.
    rng = random.Random(380 + list(_DRAWERS).index(key))
    for _ in range(12):
        x, y = rng.uniform(21, 177), rng.uniform(154, 164)
        result += _path(f'M{x:.1f} {y:.1f}l{rng.uniform(1.5, 3.5):.1f} -.4', 'none', _mix(c['wall'], c['wood'], .5), .5, 'opacity=".55"')
    return result + '</g>'
