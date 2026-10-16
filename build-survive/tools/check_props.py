#!/usr/bin/env python3
"""Проверка имён свойств в таблицах вида new("Frame", { Size = ... }).

Типизатор Luau не видит такие свойства (они ставятся через цикл), поэтому этот скрипт
сверяет каждое имя с официальным дампом API Roblox (API-Dump.json из Roblox-Client-Tracker).

Запуск: python3 tools/check_props.py путь/к/API-Dump.json
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# вызов -> (класс, номер аргумента-таблицы начиная с 0)
HELPERS = {
    r'(?:Lib\.)?label\(': ("TextLabel", 2),
    r'(?:Lib\.)?button\(': ("TextButton", 1),
    r'(?:Lib\.)?panel\(': ("Frame", 0),
    r'Lib\.viewport\(': ("ViewportFrame", 1),
    r'(?<![\w.])part\(': ("Part", 0),
    r'basePart\(': ("Part", 1),
    r'attach\(': ("Part", 3),
    r'emitter\(': ("ParticleEmitter", 1),
}
EXTRA_OK = {"Parent", "Name"}


def load_api(path):
    d = json.load(open(path))
    classes = {c["Name"]: c for c in d["Classes"]}

    def members(name):
        out = set()
        while name and name in classes:
            c = classes[name]
            for m in c["Members"]:
                if m["MemberType"] in ("Property",):
                    out.add(m["Name"])
            name = c.get("Superclass")
        return out
    return classes, members


def split_args(s, start):
    """Разбить аргументы вызова, начиная с позиции после '('. Возвращает список (начало, конец)."""
    depth = 0
    args = []
    cur = start
    i = start
    in_str = None
    while i < len(s):
        ch = s[i]
        if in_str:
            if ch == "\\":
                i += 2
                continue
            if ch == in_str:
                in_str = None
        elif ch in "\"'":
            in_str = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            if depth == 0:
                args.append((cur, i))
                return args
            depth -= 1
        elif ch == "," and depth == 0:
            args.append((cur, i))
            cur = i + 1
        i += 1
    return args


def table_keys(text):
    """Ключи верхнего уровня таблицы-литерала { A = 1, B = { ... } }."""
    text = text.strip()
    if not text.startswith("{"):
        return []
    body = text[1:-1] if text.endswith("}") else text[1:]
    keys = []
    depth = 0
    token_start = 0
    in_str = None
    i = 0
    while i < len(body):
        ch = body[i]
        if in_str:
            if ch == "\\":
                i += 2
                continue
            if ch == in_str:
                in_str = None
        elif ch in "\"'":
            in_str = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            token_start = i + 1
        elif ch == "=" and depth == 0 and body[i + 1:i + 2] != "=" and body[i - 1:i] not in "=~<>":
            k = body[token_start:i].strip()
            if re.fullmatch(r"[A-Za-z_]\w*", k):
                keys.append(k)
        i += 1
    return keys


def main():
    api_path = sys.argv[1] if len(sys.argv) > 1 else "API-Dump.json"
    classes, members = load_api(api_path)
    errors = 0
    checked = 0
    for dirpath, _, files in os.walk(os.path.join(ROOT, "src")):
        for f in files:
            if not f.endswith(".lua"):
                continue
            path = os.path.join(dirpath, f)
            src = open(path, encoding="utf-8").read()
            rel = os.path.relpath(path, ROOT)
            calls = []
            for m in re.finditer(r'(?:Lib\.new|(?<![\w.])new|Instance\.new)\(\s*"(\w+)"\s*,', src):
                calls.append((m.group(1), m.start() + m.group(0).index("(") + 1, 1))
            for pat, (cls, argn) in HELPERS.items():
                for m in re.finditer(pat, src):
                    # пропускаем объявления функций
                    line_start = src.rfind("\n", 0, m.start()) + 1
                    if re.match(r"\s*(local\s+)?function", src[line_start:m.start()] + " "):
                        if "function" in src[line_start:m.start()]:
                            continue
                    calls.append((cls, m.end(), argn))
            for cls, start, argn in calls:
                if cls not in classes:
                    print(f"{rel}: неизвестный класс {cls}")
                    errors += 1
                    continue
                args = split_args(src, start)
                if len(args) <= argn:
                    continue
                a, b = args[argn]
                keys = table_keys(src[a:b])
                valid = members(cls) | EXTRA_OK
                line = src.count("\n", 0, a) + 1
                for k in keys:
                    checked += 1
                    if k not in valid:
                        print(f"{rel}:{line}: у {cls} нет свойства «{k}»")
                        errors += 1
    print(f"проверено свойств: {checked}, ошибок: {errors}")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
