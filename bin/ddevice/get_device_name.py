#!/usr/bin/env python3
import sys, json, os, re

def main():
    codename = sys.argv[1].strip().lower() if len(sys.argv) > 1 else ""
    region = sys.argv[2].strip() if len(sys.argv) > 2 else "China"
    work_dir = sys.argv[3].strip() if len(sys.argv) > 3 else "."

    # 1. Đọc từ build.prop gốc trước nếu có
    prop_paths = [
        os.path.join(work_dir, "build/baserom/images/product/etc/build.prop"),
        os.path.join(work_dir, "build/baserom/images/system/system/build.prop"),
        os.path.join(work_dir, "build/baserom/images/vendor/build.prop"),
        os.path.join(work_dir, "build/baserom/images/odm/etc/build.prop")
    ]

    DUMMY_VALUES = {"xiaomi device", "miproduct", "mivendor", "generic", "mainline", "missi", "qssi", "qti", "yourdevice", "unknown"}
    for p in prop_paths:
        if os.path.exists(p):
            try:
                with open(p, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        m = re.match(r'^(?:ro\.product\.marketname|ro\.product\.product\.marketname|ro\.product\.model)=(.*)$', line.strip())
                        if m:
                            val = m.group(1).strip()
                            if val and val.lower() not in DUMMY_VALUES and not val.startswith("ro."):
                                print(val)
                                return
            except Exception:
                pass

    # 2. Tra cứu trong devices.json theo codename và khu vực
    json_path = os.path.join(work_dir, "bin/ddevice/data/devices.json")
    if codename and os.path.exists(json_path):
        try:
            with open(json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            for k, v in data.items():
                if k.strip().lower() == codename:
                    names = [n.strip() for n in v.split("|") if n.strip()]
                    if not names:
                        break
                    if "China" in region:
                        for n in names:
                            if not n.startswith("POCO"):
                                print(n)
                                return
                    else:
                        for n in names:
                            if n.startswith("POCO"):
                                print(n)
                                return
                    print(names[0])
                    return
        except Exception:
            pass

    print("Xiaomi Device")

if __name__ == "__main__":
    main()
