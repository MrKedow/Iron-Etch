#!/usr/bin/env python3
"""Generate the extended exercise library from the public datasets.

Sources:
  - exercises-dataset-zh (MIT data, Gym visual media attribution required)
  - free-exercise-db / exercises.json (public domain)
  - open-exercisedb (MIT, used for validation only when media is unavailable)

Usage:
  python3 tool/generate_exercise_library.py --source-root /path/to/GitHub
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
from collections import Counter

GROUP_MAP = {
    "upper arms": "手臂",
    "upper legs": "腿",
    "back": "背",
    "waist": "核心",
    "chest": "胸",
    "shoulders": "肩",
    "lower legs": "小腿",
    "lower arms": "前臂",
    "cardio": "有氧",
    "neck": "肩",
    "abdominals": "核心",
    "abductors": "臀",
    "adductors": "腿",
    "biceps": "手臂",
    "calves": "小腿",
    "chest": "胸",
    "forearms": "前臂",
    "glutes": "臀",
    "hamstrings": "腿",
    "lats": "背",
    "lower back": "背",
    "middle back": "背",
    "quadriceps": "腿",
    "traps": "背",
    "triceps": "手臂",
    "neck": "肩",
}

EQUIPMENT_MAP = {
    "body weight": "自重",
    "body only": "自重",
    "dumbbell": "哑铃",
    "cable": "绳索",
    "barbell": "杠铃",
    "leverage machine": "器械",
    "machine": "器械",
    "band": "弹力带",
    "bands": "弹力带",
    "resistance band": "弹力带",
    "smith machine": "史密斯机",
    "kettlebell": "壶铃",
    "kettlebells": "壶铃",
    "weighted": "负重",
    "stability ball": "瑞士球",
    "exercise ball": "瑞士球",
    "ez barbell": "曲杆",
    "e-z curl bar": "曲杆",
    "assisted": "辅助",
    "sled machine": "雪橇机",
    "medicine ball": "药球",
    "rope": "绳索",
    "roller": "泡沫轴",
    "foam roll": "泡沫轴",
    "bosu ball": "波速球",
    "olympic barbell": "奥杆",
    "wheel roller": "健腹轮",
    "upper body ergometer": "上肢功率车",
    "skierg machine": "滑雪机",
    "hammer": "锤",
    "stationary bike": "动感单车",
    "tire": "轮胎",
    "trap bar": "六角杠",
    "elliptical machine": "椭圆机",
    "stepmill machine": "爬楼机",
    "other": "其他",
}


def norm(value: str) -> str:
    return re.sub(r"[^a-z0-9\u4e00-\u9fff]", "", value.lower())


def clean_zh_name(value: str) -> str:
    value = re.sub(r"\s+", " ", value).strip()
    # 去掉中文之间残留的单字母噪声（数据集中有 "过a 凳"、"拉伸s" 之类）
    value = re.sub(r"(?<=[\u4e00-\u9fff])\s*[a-z]\s*(?=[\u4e00-\u9fff])", "", value)
    value = re.sub(r"(\s+[a-z]s?\b)", "", value)
    value = re.sub(r"\s*([，。；：、（）()])\s*", r"\1", value)
    value = re.sub(r"\s+", "", value)
    return value.strip()


def pattern_for(name: str) -> str:
    value = name.lower()
    if "incline" in value and any(k in value for k in ("press", "push", "fly")):
        return "上斜推"
    if any(k in value for k in ("bench press", "push up", "pushup", "chest press", "fly", "flye", "dip")):
        return "水平推"
    if "shoulder press" in value or "military press" in value or "overhead press" in value:
        return "垂直推"
    if any(k in value for k in ("pull up", "pullup", "pulldown", "chin up", "chinup")):
        return "垂直拉"
    if "row" in value or "face pull" in value:
        return "水平拉"
    if any(k in value for k in ("squat", "lunge", "leg press", "step up")):
        return "深蹲"
    if any(k in value for k in ("deadlift", "romanian", "good morning", "hip hinge")):
        return "髋铰链"
    if "curl" in value:
        return "弯举"
    if any(k in value for k in ("extension", "pushdown", "kickback")):
        return "伸展"
    if any(k in value for k in ("lateral raise", "front raise", "reverse fly", "shrug")):
        return "平举"
    if any(k in value for k in ("crunch", "sit up", "situp", "leg raise", "knee raise")):
        return "卷腹"
    if any(k in value for k in ("plank", "bridge", "hold", "dead bug")):
        return "核心稳定"
    if any(k in value for k in ("calf", "heel raise")):
        return "提踵"
    if any(k in value for k in ("run", "walk", "cycle", "bike", "elliptical", "rower", "rope")):
        return "有氧"
    return "综合"


def kind_for(name: str, english: str, body_part: str) -> str:
    text = f"{name} {english}".lower()
    if body_part == "cardio":
        return "有氧"
    if any(k in text for k in ("stretch", "拉伸", "伸展", "瑜伽", "yoga", "mobility")):
        return "柔韧"
    return "力量"


def dart_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'").replace("\n", " ") + "'"


def map_equipment(value: str | None) -> str:
    if not value:
        return "自重"
    return EQUIPMENT_MAP.get(value, value)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", required=True)
    parser.add_argument("--project-root", default=os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
    args = parser.parse_args()

    root = args.source_root
    project = args.project_root
    zh_dir = os.path.join(root, "exercises-dataset-zh")
    free_dir = os.path.join(root, "free-exercise-db")
    asset_dir = os.path.join(project, "assets", "exercises")
    os.makedirs(asset_dir, exist_ok=True)

    library_file = os.path.join(project, "lib", "data", "exercise_library.dart")
    library_text = open(library_file, encoding="utf-8").read()
    handwritten_names = re.findall(r"_e\('([^']+)'", library_text)
    existing = {norm(name) for name in handwritten_names}
    for block in re.findall(r"aliases: \[([^\]]*)\]", library_text):
        for alias in re.findall(r"'([^']+)'", block):
            existing.add(norm(alias))

    zh_data = json.load(open(os.path.join(zh_dir, "data", "exercises.json"), encoding="utf-8"))
    zh_names = json.load(open(os.path.join(zh_dir, "data", "name_zh.json"), encoding="utf-8"))
    zh_by_english = {norm(k): v for k, v in zh_names.items()}

    zh_entries: list[dict] = []
    skipped: Counter[str] = Counter()
    for item in zh_data:
        english = item["name"]
        name = clean_zh_name(zh_names.get(english, english))
        key = norm(name)
        if key in existing or norm(english) in existing:
            skipped["zh_duplicate"] += 1
            continue
        body_part = item.get("body_part", "")
        group = GROUP_MAP.get(body_part, "全身")
        kind = kind_for(name, english, body_part)
        equipment = map_equipment(item.get("equipment"))
        instructions = (item.get("instructions") or {}).get("zh") or ""
        instructions = re.sub(r"\s+", " ", instructions).strip()
        if not instructions:
            instructions = "保持动作可控，优先保证关节对齐与呼吸。"
        slug = "zh_" + item["id"]
        zh_entries.append(
            {
                "name": name,
                "group": group,
                "kind": kind,
                "equipment": equipment,
                "pattern": pattern_for(english),
                "difficulty": 2,
                "aliases": [english],
                "emphasis": [item.get("target")] if item.get("target") else [],
                "cue": instructions[:180],
                "met": 6.5 if kind == "有氧" else 0.0,
                "imageSlug": slug,
            }
        )
        existing.add(key)
        existing.add(norm(english))
        image = item.get("image")
        if image:
            source = os.path.join(zh_dir, image)
            if os.path.exists(source):
                for index in (0, 1):
                    destination = os.path.join(asset_dir, f"{slug}_{index}.jpg")
                    if not os.path.exists(destination):
                        shutil.copyfile(source, destination)

    free_entries: list[dict] = []
    free_files = sorted(
        os.path.join(free_dir, "exercises", name)
        for name in os.listdir(os.path.join(free_dir, "exercises"))
        if name.endswith(".json")
    )
    for path in free_files:
        try:
            item = json.load(open(path, encoding="utf-8"))
        except Exception:
            continue
        if not item.get("images"):
            skipped["free_no_image"] += 1
            continue
        english = item["name"]
        key = norm(english)
        if key in existing:
            skipped["free_duplicate"] += 1
            continue
        translated = zh_by_english.get(key)
        name = clean_zh_name(translated) if translated else english
        if norm(name) in existing:
            name = english
        if norm(name) in existing:
            skipped["free_name_conflict"] += 1
            continue
        muscles = item.get("primaryMuscles") or []
        group = GROUP_MAP.get(muscles[0] if muscles else "", "全身")
        category = (item.get("category") or "").lower()
        if category == "cardio":
            kind = "有氧"
        elif category in ("stretching", "mobility"):
            kind = "柔韧"
        else:
            kind = "力量"
        level = {"beginner": 1, "intermediate": 2, "expert": 3}.get(item.get("level", ""), 2)
        instructions = " ".join(item.get("instructions") or [])
        instructions = re.sub(r"\s+", " ", instructions).strip()
        if not instructions:
            instructions = "Keep the movement controlled and prioritize joint alignment and breathing."
        slug = "free_" + item.get("id", re.sub(r"[^a-zA-Z0-9]+", "_", english)).strip("_")
        free_entries.append(
            {
                "name": name,
                "group": group,
                "kind": kind,
                "equipment": map_equipment(item.get("equipment")),
                "pattern": pattern_for(english),
                "difficulty": level,
                "aliases": [english],
                "emphasis": [muscles[0]] if muscles else [],
                "cue": instructions[:180],
                "met": 6.5 if kind == "有氧" else 0.0,
                "imageSlug": slug,
            }
        )
        existing.add(norm(name))
        for index, image in enumerate((item.get("images") or [])[:2]):
            source = os.path.join(free_dir, "exercises", image)
            if os.path.exists(source):
                destination = os.path.join(asset_dir, f"{slug}_{index}.jpg")
                if not os.path.exists(destination):
                    shutil.copyfile(source, destination)

    # 现有手工动作的图片勘误：按中文名匹配 exercises-dataset-zh，优先使用其演示图。
    overrides: dict[str, str] = {}
    zh_by_name = {}
    for item in zh_data:
        english = item["name"]
        chinese = clean_zh_name(zh_names.get(english, english))
        zh_by_name[norm(chinese)] = item
    for name in handwritten_names:
        item = zh_by_name.get(norm(name))
        if item and item.get("image"):
            overrides[name] = "zh_" + item["id"]
            source = os.path.join(zh_dir, item["image"])
            if os.path.exists(source):
                for index in (0, 1):
                    destination = os.path.join(asset_dir, f"{overrides[name]}_{index}.jpg")
                    if not os.path.exists(destination):
                        shutil.copyfile(source, destination)

    def write_list(name: str, entries: list[dict]) -> str:
        lines = [f"const List<Map<String, Object?>> {name} = <Map<String, Object?>>[\n"]
        for entry in entries:
            fields = [
                f"'name': {dart_string(entry['name'])}",
                f"'group': {dart_string(entry['group'])}",
                f"'kind': {dart_string(entry['kind'])}",
                f"'equipment': {dart_string(entry['equipment'])}",
                f"'pattern': {dart_string(entry['pattern'])}",
                f"'difficulty': {entry['difficulty']}",
                "'aliases': <String>[" + ", ".join(dart_string(value) for value in entry["aliases"]) + "]",
                "'emphasis': <String>[" + ", ".join(dart_string(value) for value in entry["emphasis"]) + "]",
                f"'cue': {dart_string(entry['cue'])}",
                f"'met': {entry['met']}",
                f"'imageSlug': {dart_string(entry['imageSlug'])}",
            ]
            lines.append("  <String, Object?>{" + ", ".join(fields) + "},\n")
        lines.append("];\n")
        return "".join(lines)

    output = [
        "// 由 tool/generate_exercise_library.py 自动生成，请勿手工编辑。\n",
        "// 数据来源：exercises-dataset-zh (MIT)、free-exercise-db / exercises.json (Public Domain)。\n",
        "// 图片：© Gym visual — https://gymvisual.com/（exercises-dataset-zh 媒体，180×180）。\n\n",
        write_list("generatedExercises", zh_entries),
        "\n// free-exercise-db / exercises.json 自动生成补充动作。\n",
        write_list("freeGeneratedExercises", free_entries),
        "\n// 现有动作的图片勘误映射（来自 exercises-dataset-zh）。\n",
        "const Map<String, String> generatedImageOverrides = <String, String>{\n",
    ]
    for name, slug in overrides.items():
        output.append(f"  {dart_string(name)}: {dart_string(slug)},\n")
    output.append("};\n")
    destination = os.path.join(project, "lib", "data", "exercise_library_generated.dart")
    open(destination, "w", encoding="utf-8").write("".join(output))

    print(f"zh entries: {len(zh_entries)}")
    print(f"free entries: {len(free_entries)}")
    print(f"image overrides: {len(overrides)}")
    print("skipped:", dict(skipped))


if __name__ == "__main__":
    main()
