#!/usr/bin/env python3
"""
upload_sounds.py — загружает звуки из assets/sounds в Roblox (Open Cloud Assets API)
и записывает их ID в src/shared/Config/SoundIds.lua.

1. Откройте https://create.roblox.com/dashboard/credentials → Create API Key.
   Access Permissions → «Assets» → права Read и Write. Accepted IP: 0.0.0.0/0 (или ваш IP).
2. Узнайте свой User ID (число в адресе профиля roblox.com/users/<ID>/profile)
   или ID группы, если игра принадлежит группе.
3. Запустите из папки игры:
       python3 tools/upload_sounds.py --api-key ВАШ_КЛЮЧ --user-id 123456
   (или --group-id 7654321; ключ можно передать переменной окружения ROBLOX_API_KEY)
4. Пересоберите игру (rojo build / rojo serve) — звуки подхватятся автоматически.

Уже загруженные звуки (непустой ID в SoundIds.lua) повторно не загружаются;
--force загружает всё заново. Нужен только Python 3, без сторонних библиотек.
Загрузка аудио бесплатна, но у Roblox есть месячный лимит импортов (17 файлов в него укладываются).
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
SOUNDS_DIR = os.path.join(ROOT, "assets", "sounds")
CONFIG = os.path.join(ROOT, "src", "shared", "Config", "Sounds.lua")
IDS_FILE = os.path.join(ROOT, "src", "shared", "Config", "SoundIds.lua")
API = "https://apis.roblox.com/assets/v1/"


def sound_files():
    """Ключ SoundIds -> имя файла, по полю File в Config/Sounds.lua (раздел Music -> Music_<мир>)."""
    mapping, section = {}, None
    with open(CONFIG, encoding="utf-8") as f:
        for line in f:
            if re.match(r"\s*Effects\s*=\s*\{", line):
                section = "Effects"
            elif re.match(r"\s*Music\s*=\s*\{", line):
                section = "Music"
            match = re.match(r'\s*(\w+)\s*=\s*\{.*File\s*=\s*"([^"]+)"', line)
            if match and section:
                key = match.group(1) if section == "Effects" else "Music_" + match.group(1)
                mapping[key] = match.group(2)
    return mapping


def read_ids():
    ids = {}
    if os.path.exists(IDS_FILE):
        with open(IDS_FILE, encoding="utf-8") as f:
            for key, value in re.findall(r'^\s*(\w+)\s*=\s*"?([^",\n]*)"?\s*,', f.read(), re.M):
                ids[key] = value.strip()
    return ids


def write_ids(ids, order):
    with open(IDS_FILE, encoding="utf-8") as f:
        text = f.read()
    header = text[: text.index("return {")] if "return {" in text else ""
    lines = [f'\t{key} = "{ids.get(key, "")}",' for key in order]
    with open(IDS_FILE, "w", encoding="utf-8") as f:
        f.write(header + "return {\n" + "\n".join(lines) + "\n}\n")


def request(method, url, api_key, body=None, content_type=None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", api_key)
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.loads(response.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as err:
        detail = err.read().decode("utf-8", "replace")
        raise RuntimeError(f"HTTP {err.code}: {detail}") from None


def upload(path, name, api_key, creator):
    payload = {
        "assetType": "Audio",
        "displayName": name,
        "description": "Power Pets Simulator — звук игры",
        "creationContext": {"creator": creator, "expectedPrice": 0},
    }
    boundary = uuid.uuid4().hex
    with open(path, "rb") as f:
        content = f.read()
    body = b"".join([
        f"--{boundary}\r\n".encode(),
        b'Content-Disposition: form-data; name="request"\r\n\r\n',
        json.dumps(payload).encode("utf-8"), b"\r\n",
        f"--{boundary}\r\n".encode(),
        f'Content-Disposition: form-data; name="fileContent"; filename="{os.path.basename(path)}"\r\n'.encode(),
        b"Content-Type: audio/ogg\r\n\r\n",
        content, b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ])
    operation = request("POST", API + "assets", api_key, body, f"multipart/form-data; boundary={boundary}")
    path_part = operation.get("path") or ("operations/" + operation["operationId"])
    delay = 1.0
    for _ in range(30):
        time.sleep(delay)
        status = request("GET", API + path_part, api_key)
        if status.get("done"):
            response = status.get("response") or {}
            if "assetId" not in response:
                raise RuntimeError(f"загрузка завершилась без ID: {status}")
            return response["assetId"]
        delay = min(delay * 1.3, 5)
    raise RuntimeError("Roblox слишком долго обрабатывает файл — запустите скрипт ещё раз позже")


def main():
    parser = argparse.ArgumentParser(description="Загрузка звуков Power Pets Simulator в Roblox")
    parser.add_argument("--api-key", default=os.environ.get("ROBLOX_API_KEY"))
    owner = parser.add_mutually_exclusive_group(required=True)
    owner.add_argument("--user-id")
    owner.add_argument("--group-id")
    parser.add_argument("--force", action="store_true", help="загрузить заново даже уже загруженные")
    args = parser.parse_args()
    if not args.api_key:
        sys.exit("Нужен ключ: --api-key КЛЮЧ или переменная окружения ROBLOX_API_KEY")
    creator = {"userId": str(args.user_id)} if args.user_id else {"groupId": str(args.group_id)}

    files = sound_files()
    ids = read_ids()
    order = list(ids.keys()) or list(files.keys())
    for key in files:
        if key not in order:
            order.append(key)

    failed = 0
    for key, filename in files.items():
        if ids.get(key) and not args.force:
            print(f"  {key:14s} уже загружен: {ids[key]}")
            continue
        path = os.path.join(SOUNDS_DIR, filename)
        if not os.path.exists(path):
            print(f"  {key:14s} нет файла {filename} — сначала python3 tools/make_sounds.py")
            failed += 1
            continue
        try:
            asset_id = upload(path, "PowerPets " + os.path.splitext(filename)[0], args.api_key, creator)
        except Exception as err:  # noqa: BLE001 — показываем любую ошибку и идём дальше
            print(f"  {key:14s} ОШИБКА: {err}")
            failed += 1
            continue
        ids[key] = f"rbxassetid://{asset_id}"
        write_ids(ids, order)  # сохраняем после каждого файла, чтобы не потерять прогресс
        print(f"  {key:14s} -> {ids[key]}")

    print("\nГотово." if not failed else f"\nНе загружено: {failed}. Исправьте ошибку и запустите ещё раз.")
    print("Звуки проходят модерацию Roblox: обычно несколько минут, до этого в игре звучат запасные.")


if __name__ == "__main__":
    main()
