"""Склеивает src/*.lua в RyuVsYuta.client.lua и собирает RyuVsYuta.rbxlx:
пустое место с площадкой появления и LocalScript RyuVsYuta
в StarterPlayer → StarterPlayerScripts.

Запуск: python3 build_place.py
"""
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "RyuVsYuta.client.lua"
OUT = HERE / "RyuVsYuta.rbxlx"


def cframe(name, x, y, z):
    return (
        f'<CoordinateFrame name="{name}"><X>{x}</X><Y>{y}</Y><Z>{z}</Z>'
        "<R00>1</R00><R01>0</R01><R02>0</R02>"
        "<R10>0</R10><R11>1</R11><R12>0</R12>"
        "<R20>0</R20><R21>0</R21><R22>1</R22></CoordinateFrame>"
    )


def vec3(name, x, y, z):
    return f'<Vector3 name="{name}"><X>{x}</X><Y>{y}</Y><Z>{z}</Z></Vector3>'


def color(r, g, b):
    return f'<Color3uint8 name="Color3uint8">{(0xFF << 24) | (r << 16) | (g << 8) | b}</Color3uint8>'


def part(cls, ref, name, pos, size, rgb, extra=""):
    return f"""
		<Item class="{cls}" referent="{ref}">
			<Properties>
				<string name="Name">{name}</string>
				<bool name="Anchored">true</bool>
				{cframe("CFrame", *pos)}
				{vec3("size", *size)}
				{color(*rgb)}
				<token name="TopSurface">0</token>
				<token name="BottomSurface">0</token>
				{extra}
			</Properties>
		</Item>"""


def combine():
    parts = sorted((HERE / "src").glob("*.lua"))
    text = "\n".join(p.read_text(encoding="utf-8").rstrip("\n") + "\n" for p in parts)
    SOURCE.write_text(text, encoding="utf-8")
    return text


def main():
    src = combine()
    if "]]>" in src:
        raise SystemExit("в скрипте есть ']]>' — CDATA сломается")
    spawn_extra = '<bool name="Neutral">true</bool><int name="Duration">0</int>'
    xml = f"""<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
	<Item class="Workspace" referent="RBX0">
		<Properties>
			<string name="Name">Workspace</string>
		</Properties>{part("Part", "RBX1", "SpawnPad", (0, 99.5, 0), (40, 1, 40), (40, 42, 50))}{part("SpawnLocation", "RBX2", "SpawnLocation", (0, 100.5, 0), (6, 1, 6), (60, 62, 72), spawn_extra)}
	</Item>
	<Item class="StarterPlayer" referent="RBX3">
		<Properties>
			<string name="Name">StarterPlayer</string>
		</Properties>
		<Item class="StarterPlayerScripts" referent="RBX4">
			<Properties>
				<string name="Name">StarterPlayerScripts</string>
			</Properties>
			<Item class="LocalScript" referent="RBX5">
				<Properties>
					<string name="Name">RyuVsYuta</string>
					<bool name="Disabled">false</bool>
					<ProtectedString name="Source"><![CDATA[{src}]]></ProtectedString>
				</Properties>
			</Item>
		</Item>
	</Item>
</roblox>
"""
    OUT.write_text(xml, encoding="utf-8")
    print(f"готово: {OUT.name} ({len(xml) // 1024} КБ)")


if __name__ == "__main__":
    main()
