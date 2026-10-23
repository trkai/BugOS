#!/usr/bin/env python3
import os
import sys
import re

def parse_params(sig, is_static=False):
    params_part = sig[sig.find("(")+1 : sig.find(")")]
    reg_idx = 0 if is_static else 1
    i = 0
    param_map = []
    while i < len(params_part):
        start = i
        while i < len(params_part) and params_part[i] == "[":
            i += 1
        if i < len(params_part) and params_part[i] == "L":
            end = params_part.find(";", i)
            ptype = params_part[start:end+1]
            i = end + 1
            param_map.append((f"p{reg_idx}", ptype))
            reg_idx += 1
        elif i < len(params_part) and params_part[i] in "JD":  # 64-bit wide
            ptype = params_part[start:i+1]
            i += 1
            param_map.append((f"p{reg_idx}", ptype))
            reg_idx += 2
        elif i < len(params_part):
            ptype = params_part[start:i+1]
            i += 1
            param_map.append((f"p{reg_idx}", ptype))
            reg_idx += 1
        else:
            break
    return param_map

def patch_broadcast_controller(smali_path):
    print(f"[*] Patching BroadcastController/AMS: {smali_path}")
    with open(smali_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    # Tìm broadcastIntentLockedTraced hoặc broadcastIntentLocked
    method_match = re.search(r'(\.method\s+[^{}\r\n]*?(?:broadcastIntentLockedTraced|broadcastIntentLocked)\([^\r\n]*?\)[^{}\r\n]*?\r?\n)([\s\S]*?)(\.end method)', content)
    if not method_match:
        print("[-] Khong tim thay broadcastIntentLockedTraced / broadcastIntentLocked")
        return False

    header, body, end_tag = method_match.group(1), method_match.group(2), method_match.group(3)
    if "FcmWakeFilter;->applyFlags" in body:
        print("[+] Hook FcmWakeFilter da ton tai, bo qua.")
        return True

    is_static = "static " in header
    params = parse_params(header, is_static=is_static)
    intent_reg = None
    for reg, ptype in params:
        if ptype == "Landroid/content/Intent;":
            intent_reg = reg
            break

    if not intent_reg:
        print("[-] Khong tim thay tham so Landroid/content/Intent; trong method")
        return False

    hook_code = f"    invoke-static {{{intent_reg}}}, Lcom/android/server/am/FcmWakeFilter;->applyFlags(Landroid/content/Intent;)V\n\n"

    # Chèn ngay sau các chỉ thị .param / .registers / .locals / .annotation
    lines = body.split("\n")
    insert_idx = 0
    for idx, l in enumerate(lines):
        trimmed = l.strip()
        if trimmed.startswith((".registers", ".locals", ".param", ".annotation", ".line")):
            insert_idx = idx + 1
        elif trimmed and not trimmed.startswith(("#", ".")):
            insert_idx = idx
            break

    lines.insert(insert_idx, hook_code)
    new_body = "\n".join(lines)
    new_content = content[:method_match.start()] + header + new_body + end_tag + content[method_match.end():]

    with open(smali_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print(f"[+] Da tiem FcmWakeFilter hook thanh cong voi register {intent_reg}!")
    return True

def patch_greeze_manager(smali_path):
    print(f"[*] Patching GreezeManagerService: {smali_path}")
    with open(smali_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    patched = False

    # 1. triggerGMSLimitAction -> return-void
    gms_match = re.search(r'(\.method\s+[^{}\r\n]*?triggerGMSLimitAction\([^\r\n]*?\)V\r?\n)([\s\S]*?)(\.end method)', content)
    if gms_match:
        new_method = gms_match.group(1) + "    .registers 1\n    return-void\n" + gms_match.group(3)
        content = content[:gms_match.start()] + new_method + content[gms_match.end():]
        print("[+] Da vo hieu hoa triggerGMSLimitAction (return-void)!")
        patched = True

    # 2. isAllowBroadcast -> Screen-OFF C2DM Thaw
    allow_match = re.search(r'(\.method\s+[^{}\r\n]*?isAllowBroadcast\([^\r\n]*?\)(?:Z|I)\r?\n)([\s\S]*?)(\.end method)', content)
    if allow_match:
        header, body, end_tag = allow_match.group(1), allow_match.group(2), allow_match.group(3)
        if "checkGreezeBroadcastAllow" not in body:
            is_static = "static " in header
            params = parse_params(header, is_static=is_static)
            str_regs = [reg for reg, ptype in params if ptype == "Ljava/lang/String;"]
            if len(str_regs) >= 2:
                action_reg, pkg_reg = str_regs[0], str_regs[1]
                hook = (
                    f"    invoke-static {{{action_reg}, {pkg_reg}}}, Lcom/android/server/am/FcmWakeFilter;->checkGreezeBroadcastAllow(Ljava/lang/String;Ljava/lang/String;)I\n"
                    f"    move-result v0\n"
                    f"    if-eqz v0, :cond_fcm_cont\n"
                    f"    const/4 v0, 0x1\n"
                    f"    return v0\n"
                    f"    :cond_fcm_cont\n\n"
                )
                lines = body.split("\n")
                insert_idx = 0
                for idx, l in enumerate(lines):
                    trimmed = l.strip()
                    if trimmed.startswith((".registers", ".locals", ".param", ".annotation")):
                        insert_idx = idx + 1
                    elif trimmed and not trimmed.startswith(("#", ".")):
                        insert_idx = idx
                        break
                lines.insert(insert_idx, hook)
                content = content[:allow_match.start()] + header + "\n".join(lines) + end_tag + content[allow_match.end():]
                print(f"[+] Da tiem Screen-OFF Thaw check vao isAllowBroadcast ({action_reg}, {pkg_reg})!")
                patched = True

    with open(smali_path, "w", encoding="utf-8") as f:
        f.write(content)
    return patched

def patch_broadcast_queue_modern(smali_path):
    print(f"[*] Patching BroadcastQueueModernStubImpl: {smali_path}")
    with open(smali_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    # Replaced Build.IS_INTERNATIONAL_BUILD with const/4 vX, 0x1
    pattern = r'sget-boolean\s+([vp]\d+),\s+Lmiui/os/Build;->IS_INTERNATIONAL_BUILD:Z'
    if re.search(pattern, content):
        content = re.sub(pattern, r'const/4 \1, 0x1', content)
        with open(smali_path, "w", encoding="utf-8") as f:
            f.write(content)
        print("[+] Da gan IS_INTERNATIONAL_BUILD = true trong checkApplicationAutoStart!")
        return True
    return False

def main():
    if len(sys.argv) < 3:
        print("Usage: patch_fcm_surgical.py <target_type: services|miui_services> <extracted_dir>")
        sys.exit(1)

    target_type = sys.argv[1]
    extracted_dir = sys.argv[2]
    patched = 0
    targets = 0

    if target_type == "services":
        for root, _, files in os.walk(extracted_dir):
            for file in files:
                if file in ("BroadcastController.smali", "ActivityManagerService.smali"):
                    targets += 1
                    if patch_broadcast_controller(os.path.join(root, file)):
                        patched += 1
                        break
            if patched:
                break
        if not targets:
            print("[-] Khong tim thay BroadcastController/ActivityManagerService trong services.jar")

    elif target_type == "miui_services":
        for root, _, files in os.walk(extracted_dir):
            for file in files:
                fpath = os.path.join(root, file)
                if file == "GreezeManagerService.smali":
                    targets += 1
                    if patch_greeze_manager(fpath):
                        patched += 1
                elif file == "BroadcastQueueModernStubImpl.smali":
                    targets += 1
                    if patch_broadcast_queue_modern(fpath):
                        patched += 1
        if not targets:
            print("[-] Khong tim thay GreezeManagerService/BroadcastQueueModernStubImpl "
                  "trong miui-services.jar")

    print(f"[=] Surgical patch ({target_type}): {patched}/{targets} hook da ap dung")
    if patched == 0:
        # Trả mã lỗi để shell biết mà cảnh báo, tránh build ra ROM "âm thầm" không vá
        sys.exit(2)

if __name__ == "__main__":
    main()
