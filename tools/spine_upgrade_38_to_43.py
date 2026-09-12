#!/usr/bin/env python3
"""Spine 3.8 JSON -> spine-cpp 4.3 JSON 数据升级转换（spine-godot GDExtension 4.3 专用）。

背景
----
spine-godot GDExtension（4.3 运行时线）基于 spine-cpp 4.3，SkeletonJson 只接受
版本号以 4.3 开头的数据；Spine 3.8 导出的 JSON 直接改版本号会在解析 curve 曲线时
崩溃，且 transform 约束、rotate 帧字段、颜色 timeline 等结构均已变更。

curve 曲线是最大坑（对照 spine-cpp 4.3 SkeletonJson.cpp / CurveTimeline.cpp 确认）：
- 3.8：每帧一条归一化曲线 {curve:c1, c2:c2, c3:c3, c4:c4}（控制点在 0..1 归一
  空间，x 映射到时间段、y 映射到该值分量变化段），整条 timeline（含多值 timeline
  如 translate/scale/shear）共享同一条曲线。
- 4.3：curve 是数组且按“值分量”分组，每个分量一段 4 个数；控制点坐标为绝对坐标
  （x = time1 + c1*(time2-time1)，y = value1 + c2*(value2-value1)）。
  单值 timeline（rotate/alpha 等）curve 长 4；双值（translate/scale/shear）长 8；
  四值（rgba 颜色 r/g/b/a）长 16；六值（transform 动画 mix）长 24。
  若数组长度不足，解析器按分量索引取值会空指针崩溃（DLL 直接退出）。

本脚本把 3.8 JSON 升级为 4.3 结构，供 spine-godot 运行时加载。

用法
----
python tools/spine_upgrade_38_to_43.py <输入3.8.json> <输出.spine-json>

转换清单
--------
1. skeleton.spine -> "4.3.00"（保留原值于注释不可行，仅改写）。
2. 约束：3.8 顶层独立 ik/transform/path 数组 -> 4.3 顶层 constraints 数组（type 标记）。
   - transform 约束重写为新模型：target->source，local/relative->localSource/localTarget/
     additive，rotateMix/translateMix/scaleMix/shearMix->mixRotate/mixX/mixY/
     mixScaleX/mixScaleY/mixShearY，并生成同属性 from->to 的 properties 以激活 mix。
   - ik 帧字段 bendDirection(1/-1) -> bendPositive(bool)。
3. 动画：
   - bones 下 rotate 帧字段 angle -> value。
   - 所有帧内数字 curve 按上述规则展开为按分量分组的绝对坐标数组；stepped 保留。
   - slots 下 color timeline 键名 -> rgba（帧结构不变，帧内颜色仍是 "color" 十六进制）。
   - transform 动画帧 rotateMix/translateMix/scaleMix/shearMix ->
     mixRotate/mixX/mixY/mixScaleX/mixScaleY/mixShearY。
4. 未知结构（deform 加权网格、path 动画等）目前仅警告并直通；调用方需对转换结果
   做视觉抽检。已知未覆盖：deform（skinned 权重结构 3.8->4.3 差异大，含 weighted
   网格的角色需另做扩展）、path 约束/动画、事件曲线（事件无曲线，不受影响）。
"""

import json
import sys

TARGET_VERSION = "4.3.00"

WARNINGS = []


def warn(msg: str) -> None:
    WARNINGS.append(msg)


# ---------------------------------------------------------------- curve 转换 --

def hex_color_channels(value) -> list:
    """'rrggbbaa' / 'rrggbb' -> [r,g,b,a] 0..1（与运行时 Color::valueOf 一致）。"""
    try:
        s = str(value).strip().lower()
        if len(s) >= 8:
            return [int(s[i * 2:i * 2 + 2], 16) / 255.0 for i in range(4)]
        if len(s) >= 6:
            return [int(s[i * 2:i * 2 + 2], 16) / 255.0 for i in range(3)] + [1.0]
    except (ValueError, TypeError):
        pass
    return [1.0, 1.0, 1.0, 1.0]


def _component(frame: dict, comp, default: float) -> float:
    """取帧内某分量值；comp 为 None 时表示取颜色帧 'color' 十六进制的第 idx 通道。"""
    if comp is None:
        idx = frame.setdefault("_color_idx", 0)
        return hex_color_channels(frame.get("color"))[idx]
    if comp in frame:
        return float(frame[comp])
    return default


def convert_curve(frame: dict, nxt: dict, components: list, color_index: list) -> None:
    """把 3.8 帧内归一化数字 curve 展开为 4.3 按分量分组的绝对坐标数组（原地）。

    components: [(取值键或 None, 默认值)]；None 表示该分量来自帧内 "color" 十六进制
    （r/g/b/a 通道）。color_index 记录颜色分量当前序号（每帧处理共用，见调用方）。
    """
    if "curve" not in frame:
        return
    curve = frame["curve"]
    if isinstance(curve, str):
        return  # "stepped" 两代一致
    if isinstance(curve, bool) or not isinstance(curve, (int, float)):
        warn("curve 未知类型 %r，跳过" % (type(curve).__name__))
        return
    if nxt is None:
        return  # 末帧 curve 4.3 解析器不会读取，无需展开
    c1 = float(curve)
    c2 = float(frame.get("c2", 0.0))
    c3 = float(frame.get("c3", 1.0))
    c4 = float(frame.get("c4", 1.0))
    t1 = float(frame.get("time", 0.0))
    t2 = float(nxt.get("time", 0.0))
    span_t = t2 - t1
    array = []
    for comp, default in components:
        color_index[0] = len(array) // 4 if comp is None else color_index[0]
        if comp is None:
            idx = color_index[0]
            v1 = hex_color_channels(frame.get("color"))[idx]
            v2 = hex_color_channels(nxt.get("color"))[idx]
        else:
            v1 = _component(frame, comp, default)
            v2 = _component(nxt, comp, default)
        span_v = v2 - v1
        array += [
            t1 + span_t * c1,
            v1 + span_v * c2,
            t1 + span_t * c3,
            v1 + span_v * c4,
        ]
    frame["curve"] = array
    for key in ("c2", "c3", "c4"):
        frame.pop(key, None)


def convert_curve_frames(timeline_key: str, frames: list) -> None:
    """按 timeline 类型对帧列表做 curve 展开（rotate 额外 angle->value 改名）。"""
    if timeline_key == "rotate":
        for frame in frames:
            if "angle" in frame:
                frame["value"] = frame.pop("angle")
        components = [("value", 0.0)]
    elif timeline_key in ("translate", "scale", "shear"):
        default = {"translate": 0.0, "scale": 1.0, "shear": 0.0}[timeline_key]
        components = [("x", default), ("y", default)]
    elif timeline_key in ("rgba", "color"):
        components = [(None, 0.0)] * 4
    elif timeline_key in ("rgb",):
        components = [(None, 0.0)] * 3
    elif timeline_key == "alpha":
        components = [("value", 1.0)]
    else:
        return  # ik/transform/path/deform 等由各自函数处理
    color_index = [0]
    for i, frame in enumerate(frames):
        nxt = frames[i + 1] if i + 1 < len(frames) else None
        convert_curve(frame, nxt, components, color_index)


# ---------------------------------------------------------------- 动画段转换 --

def convert_animation_bones(anim: dict) -> None:
    bones = anim.get("bones")
    if not isinstance(bones, dict):
        return
    for bone_name, timelines in bones.items():
        if not isinstance(timelines, dict):
            warn("动画 bones.%s 结构异常（非 dict），直通" % bone_name)
            continue
        for timeline_key, frames in timelines.items():
            if not isinstance(frames, list):
                warn("动画 bones.%s.%s 结构异常（非 list），直通" % (bone_name, timeline_key))
                continue
            convert_curve_frames(str(timeline_key), frames)


def convert_animation_slots(anim: dict) -> None:
    slots = anim.get("slots")
    if not isinstance(slots, dict):
        return
    for slot_name, timelines in slots.items():
        if not isinstance(timelines, dict):
            continue
        for timeline_key, frames in timelines.items():
            if not isinstance(frames, list):
                continue
            # 3.8 的 slot 颜色 timeline 键名 "color" -> 4.3 "rgba"
            if timeline_key == "color":
                new_key = "rgba"
                timelines[new_key] = timelines.pop(timeline_key)
                timeline_key = new_key
            convert_curve_frames(str(timeline_key), frames)


def convert_animation_ik(anim: dict) -> None:
    ik = anim.get("ik")
    if not isinstance(ik, dict):
        return
    for constraint_name, frames in ik.items():
        if not isinstance(frames, list):
            continue
        for i, frame in enumerate(frames):
            if not isinstance(frame, dict):
                continue
            if "bendDirection" in frame:
                frame["bendPositive"] = bool(frame.pop("bendDirection") > 0)
            nxt = frames[i + 1] if i + 1 < len(frames) else None
            convert_curve(frame, nxt, [("mix", 1.0), ("softness", 0.0)], [0])


def convert_animation_transform(anim: dict) -> None:
    tr = anim.get("transform")
    if not isinstance(tr, dict):
        return
    mix_map = {
        "rotateMix": "mixRotate",
        "translateMix": ("mixX", "mixY"),
        "scaleMix": ("mixScaleX", "mixScaleY"),
        "shearMix": "mixShearY",
    }
    for constraint_name, frames in tr.items():
        if not isinstance(frames, list):
            continue
        for i, frame in enumerate(frames):
            if not isinstance(frame, dict):
                continue
            for old_key, new_key in mix_map.items():
                if old_key not in frame:
                    continue
                value = frame.pop(old_key)
                if isinstance(new_key, tuple):
                    for nk in new_key:
                        frame[nk] = value
                else:
                    frame[new_key] = value
            nxt = frames[i + 1] if i + 1 < len(frames) else None
            convert_curve(frame, nxt, [
                ("mixRotate", 1.0), ("mixX", 1.0), ("mixY", 1.0),
                ("mixScaleX", 1.0), ("mixScaleY", 1.0), ("mixShearY", 1.0),
            ], [0])


def convert_animation_deform(anim: dict) -> None:
    deform = anim.get("deform")
    if not isinstance(deform, dict):
        return
    warn("deform 转换未实现（加权网格 3.8->4.3 结构差异大），仅直通，"
         "含 deform 动画的角色需要另做扩展，可能加载失败")
    for slot_name, skin_map in deform.items():
        if not isinstance(skin_map, dict):
            continue
        for skin_name, timelines in skin_map.items():
            if not isinstance(timelines, dict):
                continue
            for timeline_key, frames in timelines.items():
                if not isinstance(frames, list):
                    continue
                for frame in frames:
                    if isinstance(frame, dict) and "curve" in frame:
                        warn("deform 帧含 curve，未转换，可能崩溃")


def convert_animation_draworder(anim: dict) -> None:
    # 3.8 兼容键 draworder（小写）-> 4.3 只认 drawOrder
    if "draworder" in anim and "drawOrder" not in anim:
        anim["drawOrder"] = anim.pop("draworder")


def convert_animation(anim: dict) -> None:
    convert_animation_bones(anim)
    convert_animation_slots(anim)
    convert_animation_ik(anim)
    convert_animation_transform(anim)
    convert_animation_deform(anim)
    convert_animation_draworder(anim)


# ---------------------------------------------------------------- constraints --

def convert_constraint_ik(data: dict) -> dict:
    # 3.8/4.3 ik setup 字段基本一致（bones/target/mix/softness/bendPositive/
    # compress/stretch）；3.8 无 type/skinRequired -> 补默认。
    out = {"type": "ik", "skinRequired": False}
    for key, value in data.items():
        if key == "bendDirection":
            out["bendPositive"] = value > 0
        elif key in ("order",):
            continue  # 4.3 按 constraints 数组顺序，order 无用
        else:
            out[key] = value
    return out


def convert_constraint_transform(data: dict) -> dict:
    """3.8 transform 约束 -> 4.3 constraints[type=transform]（对照 4.3 SkeletonJson.cpp
    与 TransformConstraintData.cpp 推导的等价映射）。

    3.8 模型：bones 按 mix* 跟随 target 的旋转/平移/缩放/斜切，并在约束级带
    rotation/x/y/scaleX/scaleY/shearY 偏移。4.3 模型（From/To property）：
    - properties 必须是“对象”（子键带名字），数组形式会让解析器对空 _name 做
      strcmp 空指针崩溃（实测 DLL 崩溃根因之一）；
    - 每个受控分量（rotate/x/y/scaleX/scaleY/shearY）生成同属性 from->to 自链
      {"rotate": {"to": {"rotate": {}}}}；
    - 3.8 的约束级偏移 rotation/x/y/... 在 4.3 仍放约束级（FromX::value 内部叠加）；
    - 3.8 的 rotateMix/translateMix/scaleMix/shearMix 对应 4.3 每分量 mix：
      rotateMix->mixRotate，translateMix->mixX/mixY，scaleMix->mixScaleX/mixScaleY，
      shearMix->mixShearY；世界模式（默认）下两者都按 mix 向 (源值+偏移) 收敛，等价。
    - local/relative（3.8）-> localSource=localTarget / additive（近似映射）。
    """
    mix_map = {
        "rotateMix": ("rotate", "mixRotate"),
        "translateMix": ("x", "mixX"),
        "translateMixY": ("y", "mixY"),  # 占位，见下
        "scaleMix": ("scaleX", "mixScaleX"),
        "scaleMixY": ("scaleY", "mixScaleY"),
        "shearMix": ("shearY", "mixShearY"),
    }
    mixes = {
        "rotateMix": float(data.get("rotateMix", 1.0)),
        "translateMix": float(data.get("translateMix", 1.0)),
        "scaleMix": float(data.get("scaleMix", 1.0)),
        "shearMix": float(data.get("shearMix", 1.0)),
    }
    properties = {}
    # 平移/缩放同时作用于 x、y（3.8 一个 mix 管两个分量）
    follow = [
        ("rotateMix", "rotate"),
        ("translateMix", "x"),
        ("translateMix", "y"),
        ("scaleMix", "scaleX"),
        ("scaleMix", "scaleY"),
        ("shearMix", "shearY"),
    ]
    for old_key, prop in follow:
        if mixes[old_key] != 0.0:
            properties.setdefault(prop, {"to": {prop: {}}})
    out = {
        "type": "transform",
        "skinRequired": False,
        "bones": list(data.get("bones", [])),
        "source": data.get("target", ""),
        "localSource": bool(data.get("local", False)),
        "localTarget": bool(data.get("local", False)),
        "additive": bool(data.get("relative", False)),
        "clamp": False,
        "rotation": float(data.get("rotation", 0.0)),
        "x": float(data.get("x", 0.0)),
        "y": float(data.get("y", 0.0)),
        "scaleX": float(data.get("scaleX", 0.0)),
        "scaleY": float(data.get("scaleY", 0.0)),
        "shearY": float(data.get("shearY", 0.0)),
        "properties": properties,
        "mixRotate": mixes["rotateMix"],
        "mixX": mixes["translateMix"],
        "mixY": mixes["translateMix"],
        "mixScaleX": mixes["scaleMix"],
        "mixScaleY": mixes["scaleMix"],
        "mixShearY": mixes["shearMix"],
    }
    if "name" in data:
        out["name"] = data["name"]
    return out



def convert_constraint_path(data: dict) -> dict:
    out = {"type": "path", "skinRequired": False}
    for key, value in data.items():
        if key == "order":
            continue
        if key == "rotateMix":
            out["mixRotate"] = value
        elif key == "translateMix":
            out["mixX"] = value
            out["mixY"] = value
        else:
            out[key] = value
    return out


def convert_skins(data: dict) -> None:
    """默认皮肤归一化：4.3 运行时只把名为 "default" 的皮肤作为骨架默认皮肤
    （SkeletonJson 中 defaultSkin 判定），没有默认皮肤的骨架所有槽位附件为空、
    渲染全空白且 get_bounds 返回无效值。3.8 素材包常把唯一皮肤命名为 A/B/...，
    这里在不存在 "default" 皮肤时把第一个皮肤改名 "default"（附件内嵌的
    name/path 引用的是 atlas region 名如 A/xxx，不受皮肤名影响）。"""
    skins = data.get("skins")
    if not isinstance(skins, list):
        return
    names = {sk.get("name") for sk in skins if isinstance(sk, dict)}
    if "default" not in names and skins and isinstance(skins[0], dict):
        old = skins[0].get("name")
        skins[0]["name"] = "default"
        warn("皮肤 %r 已改名为 default（4.3 默认皮肤要求）" % old)


def convert_constraints(data: dict) -> None:
    constraints = []
    for kind, converter in (
        ("ik", convert_constraint_ik),
        ("transform", convert_constraint_transform),
        ("path", convert_constraint_path),
    ):
        items = data.get(kind)
        if not isinstance(items, list):
            continue
        for item in items:
            constraints.append(converter(item))
        data.pop(kind)
    if constraints:
        data["constraints"] = constraints


# --------------------------------------------------------------------- entry --

def upgrade(data: dict) -> dict:
    skeleton = data.get("skeleton")
    if isinstance(skeleton, dict):
        skeleton["spine"] = TARGET_VERSION
    convert_constraints(data)
    convert_skins(data)
    animations = data.get("animations")
    if isinstance(animations, dict):
        for anim in animations.values():
            convert_animation(anim)
    return data


def main() -> int:
    if len(sys.argv) != 3:
        print("用法: python tools/spine_upgrade_38_to_43.py <输入3.8.json> <输出.spine-json>")
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, "r", encoding="utf-8-sig") as f:
        data = json.load(f)
    version = data.get("skeleton", {}).get("spine", "")
    if not str(version).startswith("3.8"):
        warn("输入 skeleton.spine=%r 不是 3.8 版本，仍按 3.8 结构尝试转换" % version)
    upgrade(data)
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print("已写出: %s" % dst)
    if WARNINGS:
        print("警告 (%d):" % len(WARNINGS))
        for w in WARNINGS[:50]:
            print("  -", w)
    return 0


if __name__ == "__main__":
    sys.exit(main())
