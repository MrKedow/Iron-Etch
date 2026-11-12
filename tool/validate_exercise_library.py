#!/usr/bin/env python3
"""Validate the generated exercise library against its source datasets."""

from __future__ import annotations

import argparse
import json
import os
import re
from collections import Counter
from PIL import Image

VALID_GROUPS = {"胸", "背", "肩", "手臂", "前臂", "腿", "臀", "小腿", "核心", "全身", "有氧", "柔韧", "专项"}
VALID_KINDS = {"力量", "有氧", "柔韧", "功能", "专项"}


def norm(value: str) -> str:
    return re.sub(r"[^a-z0-9\u4e00-\u9fff]", "", value.lower())


def parse_list(text: str, name: str) -> list[dict]:
    match = re.search(
        rf"const List<Map<String, Object\?>> {name} = <Map<String, Object\?>>\[(.*?)\n\];",
        text,
        re.S,
    )
    if not match:
        return []
    result = []
    for raw in re.finditer(r"<String, Object\?>\{(.*?)\},(?:\n|$)", match.group(1), re.S):
        body = raw.group(1)
        item = {}
        for key in ("name", "group", "kind", "equipment", "pattern", "cue", "imageSlug"):
            found = re.search(rf"'{key}': '((?:\\.|[^'])*)'", body)
            item[key] = found.group(1) if found else ""
        aliases = re.search(r"'aliases': <String>\[(.*?)\]", body, re.S)
        raw_aliases = re.findall(r"'((?:\\.|[^'])*)'", aliases.group(1)) if aliases else []
        item["aliases"] = [value.replace("\\'", "'").replace("\\\\", "\\") for value in raw_aliases]
        result.append(item)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", required=True)
    parser.add_argument("--project-root", default=os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
    args = parser.parse_args()
    root = args.source_root
    project = args.project_root

    generated_text = open(os.path.join(project, "lib", "data", "exercise_library_generated.dart"), encoding="utf-8").read()
    zh = parse_list(generated_text, "generatedExercises")
    free = parse_list(generated_text, "freeGeneratedExercises")
    all_items = zh + free
    overrides_text = generated_text.split("generatedImageOverrides", 1)[1]
    image_overrides = dict(re.findall(r"'((?:\\.|[^'])*)': '([^']+)'", overrides_text))
    image_overrides = {name.replace("\\'", "'"): slug for name, slug in image_overrides.items()}
    library_text = open(os.path.join(project, "lib", "data", "exercise_library.dart"), encoding="utf-8").read()
    manual_names = re.findall(r"_e\('((?:\\.|[^'])*)'", library_text)
    manual_names = [name.replace("\\'", "'") for name in manual_names]
    illustrations_text = open(os.path.join(project, "lib", "data", "exercise_illustrations.dart"), encoding="utf-8").read()
    manual_illustrations = dict(re.findall(r"'((?:\\.|[^'])*)': '([^']+)'", illustrations_text))
    manual_illustrations = {name.replace("\\'", "'"): slug for name, slug in manual_illustrations.items()}

    zh_source = json.load(open(os.path.join(root, "exercises-dataset-zh", "data", "exercises.json"), encoding="utf-8"))
    zh_by_id = {item["id"]: item for item in zh_source}
    zh_names = json.load(open(os.path.join(root, "exercises-dataset-zh", "data", "name_zh.json"), encoding="utf-8"))
    free_source = {}
    free_dir = os.path.join(root, "free-exercise-db", "exercises")
    for file_name in os.listdir(free_dir):
        if not file_name.endswith(".json"):
            continue
        item = json.load(open(os.path.join(free_dir, file_name), encoding="utf-8"))
        free_source[item["id"]] = item

    open_source = {}
    open_path = os.path.join(root, "open-exercisedb", "exercises.json")
    if os.path.exists(open_path):
        for item in json.load(open(open_path, encoding="utf-8")):
            open_source[norm(item["name"])] = item

    errors: list[str] = []
    warnings: list[str] = []

    for name in manual_names:
        slug = image_overrides.get(name) or manual_illustrations.get(name)
        if not slug:
            errors.append(f"manual exercise has no image: {name}")
            continue
        if slug.startswith("zh_") and slug[3:] not in zh_by_id:
            errors.append(f"manual zh source id missing: {name} -> {slug[3:]}")
        elif slug.startswith("free_") and slug[5:] not in free_source:
            errors.append(f"manual free source id missing: {name} -> {slug[5:]}")
        for index in (0, 1):
            image_path = os.path.join(project, "assets", "exercises", f"{slug}_{index}.jpg")
            if not os.path.exists(image_path):
                errors.append(f"manual missing image: {image_path}")
                break

    names = Counter(norm(item["name"]) for item in all_items)
    duplicates = [name for name, count in names.items() if count > 1]
    if duplicates:
        errors.append(f"duplicate names: {duplicates[:10]}")

    for item in all_items:
        slug = item["imageSlug"]
        if not slug:
            errors.append(f"missing image slug: {item['name']}")
            continue
        if not slug.startswith(("zh_", "free_")):
            errors.append(f"unknown image source: {item['name']} -> {slug}")
            continue
        for index in (0, 1):
            image_path = os.path.join(project, "assets", "exercises", f"{slug}_{index}.jpg")
            if not os.path.exists(image_path):
                errors.append(f"missing image: {image_path}")
                break
        else:
            try:
                with Image.open(image_path) as image:
                    if slug.startswith("zh_") and image.size != (180, 180):
                        warnings.append(f"unexpected zh media size: {image_path} {image.size}")
            except Exception as error:
                warnings.append(f"cannot read image {image_path}: {error}")

        if item["group"] not in VALID_GROUPS:
            errors.append(f"invalid group: {item['name']} -> {item['group']}")
        if item["kind"] not in VALID_KINDS:
            errors.append(f"invalid kind: {item['name']} -> {item['kind']}")
        if not item["aliases"]:
            warnings.append(f"missing English alias: {item['name']}")
        if not item["cue"]:
            warnings.append(f"missing cue: {item['name']}")

        if slug.startswith("zh_"):
            source_id = slug[3:]
            if source_id not in zh_by_id:
                errors.append(f"zh source id missing: {item['name']} -> {source_id}")
            else:
                source = zh_by_id[source_id]
                source_name = zh_names.get(source["name"], source["name"])
                if norm(source_name) != norm(item["name"]):
                    warnings.append(
                        f"zh display name differs from source: {item['name']} / {source_name}"
                    )
        else:
            source_id = slug[5:]
            if source_id not in free_source:
                errors.append(f"free source id missing: {item['name']} -> {source_id}")
            else:
                source = free_source[source_id]
                if item["aliases"][0] != source["name"]:
                    warnings.append(
                        f"free alias differs from source: {item['aliases'][0]} / {source['name']}"
                    )

    print(f"zh generated: {len(zh)}")
    print(f"free generated: {len(free)}")
    print(f"total generated: {len(all_items)}")
    print(f"manual exercises: {len(manual_names)}")
    print(f"manual image overrides: {len(image_overrides)}")
    print(f"manual illustration slugs: {len(manual_illustrations)}")
    print(f"kind distribution: {dict(Counter(item['kind'] for item in all_items))}")
    print(f"group distribution: {dict(Counter(item['group'] for item in all_items))}")
    open_matches = 0
    for item in all_items:
        for alias in item["aliases"]:
            if norm(alias) in open_source:
                open_matches += 1
                break
    print(f"open-exercisedb cross-check matches: {open_matches}")
    print(f"errors: {len(errors)}")
    for error in errors[:20]:
        print("  ERROR", error)
    print(f"warnings: {len(warnings)}")
    for warning in warnings[:20]:
        print("  WARN ", warning)
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
