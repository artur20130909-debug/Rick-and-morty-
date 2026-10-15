"""Превращает API-Dump.json Roblox в компактную Luau-таблицу классов и Enum для мока.
Запуск: python3 gen_api.py API-Dump.json api.luau
"""
import json, sys
dump = json.load(open(sys.argv[1], encoding='utf-8'))
out = ["return {", "Classes = {"]
def q(s): return '"' + s.replace('\\','\\\\').replace('"','\\"') + '"'
for c in dump["Classes"]:
    tags = c.get("Tags") or []
    flags = ""
    if "NotCreatable" in tags: flags += "c"
    if "Service" in tags: flags += "s"
    props, events, funcs, cbs = [], [], [], []
    for m in c["Members"]:
        mt = m["MemberType"]; mtags = m.get("Tags") or []
        sec = m.get("Security")
        if isinstance(sec, dict):
            secbad = "r" if sec.get("Read") != "None" else ""
            secbad += "w" if sec.get("Write") != "None" else ""
        else:
            secbad = "rw" if sec not in (None, "None") else ""
        if mt == "Property":
            vt = m["ValueType"]
            f = ""
            if "ReadOnly" in mtags: f += "r"
            if "NotScriptable" in mtags: f += "n"
            if "r" in secbad: f += "S"
            if "w" in secbad: f += "W"
            if "Deprecated" in mtags: f += "d"
            props.append("[%s]=%s" % (q(m["Name"]), q(vt["Category"] + ":" + vt["Name"] + ":" + f)))
        elif mt == "Event":
            events.append("[%s]=%s" % (q(m["Name"]), "true" if secbad == "" else "false"))
        elif mt == "Function":
            funcs.append("[%s]=%s" % (q(m["Name"]), "true" if secbad == "" else "false"))
        elif mt == "Callback":
            cbs.append("[%s]=true" % q(m["Name"]))
    out.append("[%s]={S=%s,F=%s,P={%s},E={%s},M={%s},C={%s}}," % (
        q(c["Name"]), q(c.get("Superclass","<<<ROOT>>>")), q(flags), ",".join(props), ",".join(events), ",".join(funcs), ",".join(cbs)))
out.append("},")
out.append("Enums = {")
for e in dump["Enums"]:
    out.append("[%s]={%s}," % (q(e["Name"]), ",".join("[%s]=%d" % (q(i["Name"]), i["Value"]) for i in e["Items"])))
out.append("},")
out.append("}")
open(sys.argv[2], "w", encoding="utf-8").write("\n".join(out))
print("classes", len(dump["Classes"]), "enums", len(dump["Enums"]))
