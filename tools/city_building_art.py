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


def _tent(key: str, c: dict, tech: bool = False) -> str:
    d, g, wood = c['dark'], c['gold'], c['wood']
    out = f'<ellipse cx="103" cy="153" rx="94" ry="19" fill="{_fill(key, "shadow")}"/>'
    out += _path('M25 130L132 152L175 130L75 106Z', _fill(key, 'earth'), d, .7)
    out += _path('M30 87L134 110L132 148L21 127Z', _fill(key, 'canvas'), d, 1.1)
    out += _path('M134 110L180 84L172 132L132 148Z', _fill(key, 'canvas_side'), d, 1.1)
    out += _path('M17 91L88 32L155 48L134 111Z', _fill(key, 'canvas'), d, 1.2)
    out += _path('M155 48L180 84L134 111Z', _fill(key, 'canvas_side'), d, 1.2)
    out += _path('M17 91Q47 94 72 102T134 111L180 84', 'none', _mix(wood, g, .3), 3)
    out += _path('M88 32L155 48M88 32L37 93M111 38L81 101M134 43L112 107M155 48L157 98', 'none', _mix(c['wall'], g, .27), 1.5)
    out += _path('M88 32L17 91M155 48L134 111', 'none', _mix(c['wall'], d, .3), 1.5)
    out += _path('M27 95L26 123M48 99L44 127M123 114L124 142M149 107L150 137M170 92L166 127', 'none', _mix(c['wall'], wood, .3), .85)
    # Open curtain, tied to the timbers. The inside remains dark enough to read.
    out += _path('M67 100L111 109L116 145L63 135Z', d, wood, 1)
    out += _path('M67 100Q76 116 66 130L63 135L83 139Q74 120 83 103Z', _fill(key, 'canvas'), d, .8)
    out += _path('M110 109Q99 118 109 137L116 145L98 142Q108 125 94 105Z', _fill(key, 'canvas'), d, .8)
    out += _path('M66 127L75 128M106 135L112 136', 'none', g, 2)
    out += _path('M84 134L100 138L98 141L83 138Z', _fill(key, 'wood'), d, .8)
    out += _path('M86 139V145M98 141V147', 'none', wood, 1.8)
    out += _path('M15 99L4 145M183 94L193 149M13 145L1 146M187 149L197 151', 'none', _mix(wood, g, .3), .85)
    out += _path('M1 146L3 150M197 151L196 156', 'none', d, 2)
    out += _path('M87 32V10', 'none', wood, 2.2)
    out += _path('M88 10Q107 13 126 14L119 22Q104 20 88 23Z', _fill(key, 'red' if tech else 'cloth'), d, .8)
    out += _path('M92 13Q106 15 120 15', 'none', _mix(g, '#fff1cb', .24), .8)
    out += _lantern(key, c, 42, 108, .72) + _lantern(key, c, 149, 125, .67)
    if tech:
        # A tangible campaign sand table in the foreground, not an icon.
        out += _path('M12 134L41 116L86 126L60 148Z', _fill(key, 'wood'), d, 1)
        out += _path('M12 134V141L60 155V148ZM60 148L86 126V133L60 155Z', _mix(wood, d, .18), d, .75)
        out += _path('M17 133L41 121L79 128L59 143Z', _mix(c['wall'], c['roof'], .22), d, .75)
        out += _path('M29 129Q45 136 53 130T70 131', 'none', _mix(c['roof'], '#81b8bc', .56), 1.65)
        out += _path('M26 134l7 -5l5 6M53 134l6 -5l6 6', 'none', _mix(c['roof'], d, .1), 1.3)
        out += _path('M33 129V115M56 134V121M70 130V118', 'none', wood, .85)
        out += _path('M33 115L41 118L33 121ZM56 121L63 124L56 127ZM70 118L77 120L70 123Z', g, d, .5)
        out += _path('M18 140V155M59 153V166M82 134V148', 'none', _fill(key, 'wood'), 2.3)
        out += _path('M168 134L183 130L189 137L175 141Z', _fill(key, 'canvas'), wood, .7)
        out += _path('M173 134L182 135M173 137L180 138', 'none', wood, .5)
    else:
        out += _path('M147 151V59', 'none', wood, 2.2)
        out += _path('M148 61L170 66L168 99L149 94Z', _fill(key, 'red'), d, .8)
        out += _path('M153 65L153 91M159 67L159 93', 'none', g, .7)
        out += _crate(key, c, 155, 134, .66)
        out += _path('M44 140L66 145L61 152L40 147Z', _fill(key, 'canvas'), wood, .7)
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
    d, w = c['dark'], c['wood']
    out = _foundation(key, c)
    out += _path('M33 77L132 97V144L33 125Z', _fill(key, 'wood'), d, 1)
    out += _path('M132 97L175 78V129L132 144Z', _fill(key, 'wall_side'), d, 1)
    out += '<g transform="translate(38,80) skewY(11.31)">'
    for x in [2, 35, 68]:
        out += f'<rect x="{x}" y="12" width="27" height="35" fill="{d}" stroke="{w}" stroke-width="1.5"/>'
        out += _path(f'M{x + 2} 47L{x + 8} 33L{x + 23} 36L{x + 25} 47Z', _mix(c['gold'], w, .26), w, .65)
        for hay in range(4):
            out += _path(f'M{x + 5 + hay * 4} 45l2 -7', 'none', c['gold'], .65)
    out += '</g>'
    out += _path('M35 79V132M67 84V136M101 91V144M133 96V147M171 80V130', 'none', _fill(key, 'wood'), 3.5)
    out += _roof(key, c)
    # A heavy rail fence wraps the pens with visible side thickness.
    for x, y in [(18, 124), (48, 130), (80, 136), (114, 143), (143, 137), (171, 123)]:
        out += _path(f'M{x} {y + 25}V{y - 3}L{x + 3} {y - 7}L{x + 6} {y - 2}V{y + 24}Z', _fill(key, 'wood'), d, .7)
        out += _path(f'M{x + 1} {y - 1}V{y + 22}', 'none', _mix(w, c['gold'], .45), .65)
    out += _path('M19 129L115 148L176 122M19 141L115 160L176 134', 'none', _mix(w, c['gold'], .2), 3.8)
    out += _path('M20 128L115 147L175 121M20 140L115 159L175 133', 'none', _mix(w, c['gold'], .4), .7)
    out += _path('M81 140L110 145L107 155L81 150Z', _fill(key, 'wood'), d, .7)
    out += _sack(key, c, 179, 127, .8)
    out += _jar(key, c, 27, 143, .65)
    out += _lantern(key, c, 145, 109, .65)
    return out


def _shop(key: str, c: dict) -> str:
    d, w, g = c['dark'], c['wood'], c['gold']
    out = _house_body(key, c, 'open') + _roof(key, c)
    # Broad fabric veranda follows the perspective of the front facade.
    out += _path('M24 103L119 124L133 106L40 87Z', _fill(key, 'cloth'), d, .9)
    for i in range(0, 8, 2):
        x = 24 + i * 12
        out += _path(f'M{x} {103 + i * 2.65}L{x + 11} {105 + i * 2.65}L{x + 26} {89 + i * 2.6}L{x + 14} {87 + i * 2.6}Z', _fill(key, 'red'), 'none')
    out += _path('M24 103Q29 112 35 106Q41 116 47 109Q53 118 59 112Q65 120 71 115Q77 124 83 118Q89 127 95 121Q101 129 107 123Q113 132 119 126V124Z', _fill(key, 'cloth'), w, .6)
    out += _path('M25 108V148M119 128V166M131 111V152', 'none', _fill(key, 'wood'), 2.9)
    out += _path('M30 140L119 158L126 153L37 135Z', _fill(key, 'wood'), d, .9)
    out += _path('M30 140V147L119 165V158Z', _mix(w, d, .1), d, .65)
    out += _path('M34 144L116 160', 'none', _mix(w, g, .45), .65)
    # Rolled fabrics, lidded boxes, produce basket and a scale.
    for x, y, col in [(40, 133, c['roof']), (54, 136, '#a65f49'), (68, 139, c['wall'])]:
        out += _path(f'M{x} {y}l3 -7l13 3l-2 7Z', col, d, .6)
        out += f'<ellipse cx="{x + 2}" cy="{y - 3}" rx="2.5" ry="4" fill="{_mix(col, g, .25)}" stroke="{d}" stroke-width=".5"/>'
    out += _path('M91 145V122M83 126L99 130M86 127L81 138M97 130L102 141', 'none', w, 1)
    out += _path('M75 138Q82 143 88 140M96 141Q102 146 108 143', 'none', g, 1.2)
    out += _crate(key, c, 142, 131, .88)
    out += _crate(key, c, 166, 123, .62)
    out += _sack(key, c, 21, 131, .7)
    out += _lantern(key, c, 148, 102, .79)
    return out


def _inventory(key: str, c: dict) -> str:
    d, w, g = c['dark'], c['wood'], c['gold']
    out = _house_body(key, c, 'barn')
    # The visible side is boarded rather than a copy of a domestic building.
    out += _path('M134 101L173 84V129L134 145Z', _fill(key, 'wood'), d, .7)
    for i in range(1, 7):
        x = 134 + i * 5.4
        out += _path(f'M{x:.1f} {101 - i * 2.3:.1f}V{144 - i * 2.3:.1f}', 'none', _mix(w, d, .25), .85)
    out += _path('M135 107L170 128M169 89L136 141', 'none', _mix(w, g, .27), 2.5)
    out += _roof(key, c)
    # Side granary barrel, tied sacks and broad transport chest distinguish storage.
    out += f'<ellipse cx="27" cy="134" rx="18" ry="8" fill="{_fill(key, "wood")}" stroke="{d}" stroke-width=".7"/>'
    out += _path('M9 134V153Q28 164 45 152V134', _fill(key, 'wood'), d, .8)
    out += _path('M10 141Q27 150 44 140M10 150Q28 159 44 149', 'none', _mix(w, g, .3), 2)
    for x in [15, 23, 32, 39]:
        out += _path(f'M{x} 138V153', 'none', _mix(w, d, .28), .65)
    out += _sack(key, c, 15, 118, .75) + _sack(key, c, 39, 130, .8)
    out += _crate(key, c, 143, 137, 1)
    out += _crate(key, c, 167, 129, .62)
    out += _lantern(key, c, 69, 114, .8)
    return out


def _tavern(key: str, c: dict) -> str:
    d, w, g = c['dark'], c['wood'], c['gold']
    out = _house_body(key, c)
    # Chimney belongs behind the pitched roof.
    out += _path('M140 39V20L154 23V46Z', _fill(key, 'stone'), d, .8)
    out += _path('M138 20L149 15L158 19L154 25Z', _mix(w, c['wall'], .6), d, .8)
    out += _path('M147 14Q137 7 146 3M151 13Q159 7 151 1', 'none', _mix(c['light'], c['wall'], .2), 2, 'opacity=".35"')
    out += _roof(key, c)
    out += _path('M154 65V132M156 75L184 81', 'none', _fill(key, 'wood'), 2.6)
    out += _path('M168 80L185 84V110L168 106Z', _fill(key, 'red'), d, .8)
    out += _path('M171 85L182 87M171 104L181 106', 'none', g, .8)
    out += _path('M175 89v3q-5 1 -4 5q1 5 5 5q5 -1 4 -5q0 -3 -3 -4v-3Z', _mix(g, '#fff1bc', .1), d, .55)
    out += _path('M38 132L76 140L70 145L32 137Z', _fill(key, 'wood'), d, .8)
    out += _path('M38 137V151M68 143V156', 'none', w, 2.4)
    out += _jar(key, c, 22, 133, .97, True) + _jar(key, c, 45, 145, .74)
    out += _jar(key, c, 161, 137, .79, True)
    out += _lantern(key, c, 51, 110, .9) + _lantern(key, c, 139, 107, .82)
    # Half rolled front curtains keep the warm windows integrated with the building.
    out += _path('M47 91L64 94L63 102L47 100ZM109 104L125 107L124 113L109 110Z', _fill(key, 'red'), w, .6)
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
    'command': lambda key, c: _tent(key, c, False),
    'tech': lambda key, c: _tent(key, c, True),
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
    result += '<g stroke-linejoin="round" stroke-linecap="round">'
    result += _DRAWERS[key](key, c)
    # Hand placed chips and tiny earth flecks give the foundations a worn edge.
    rng = random.Random(380 + list(_DRAWERS).index(key))
    for _ in range(12):
        x, y = rng.uniform(21, 177), rng.uniform(154, 164)
        result += _path(f'M{x:.1f} {y:.1f}l{rng.uniform(1.5, 3.5):.1f} -.4', 'none', _mix(c['wall'], c['wood'], .5), .5, 'opacity=".55"')
    return result + '</g>'
