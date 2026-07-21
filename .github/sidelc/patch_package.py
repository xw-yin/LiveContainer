import os

def patch_alt_sign():
    path = 'SideStoreBuild/Dependencies/AltSign/Package.swift'
    if not os.path.exists(path):
        print(f"Error: {path} not found.")
        return False

    with open(path, 'r', encoding='utf-8') as f:
        lines = f.read().splitlines()

    modified = False
    for i, line in enumerate(lines):
        if 'name: "NativeBridge"' in line:
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j < len(lines) and 'dependencies: [' in lines[j]:
                lines.insert(j + 1, '                "OpenSSL",')
                modified = True
                print("Successfully added OpenSSL dependency to NativeBridge target.")
                break

    if modified:
        with open(path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
    else:
        print("Warning: NativeBridge target not found or already modified in Package.swift.")
    return modified

def patch_minimuxer():
    # 1. Patch IdeviceGateway.swift
    gateway_path = 'SideStoreBuild/Dependencies/minimuxer/Sources/IdeviceGateway.swift'
    if not os.path.exists(gateway_path):
        print(f"Error: {gateway_path} not found.")
        return False
    with open(gateway_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    old_matches_1 = 'let mountPathMatches = mountPath == "/System/Developer"'
    new_matches_1 = 'let mountPathMatches = mountPath == "/System/Developer" || mountPath == "/Developer"'
    old_matches_2 = 'let imageTypeMatches = imageType == "DeveloperDiskImage"'
    new_matches_2 = 'let imageTypeMatches = imageType == "DeveloperDiskImage" || imageType == "Developer"'
    
    if old_matches_1 in content and old_matches_2 in content:
        content = content.replace(old_matches_1, new_matches_1)
        content = content.replace(old_matches_2, new_matches_2)
        with open(gateway_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("Successfully patched IdeviceGateway.swift.")
    else:
        print("Warning: IdeviceGateway.swift already patched or pattern not found.")

    # 2. Patch NetworkIfaceScanner.swift
    scanner_path = 'SideStoreBuild/Dependencies/minimuxer/Sources/Services/NetworkIfaceScanner.swift'
    if not os.path.exists(scanner_path):
        print(f"Error: {scanner_path} not found.")
        return False
    with open(scanner_path, 'r', encoding='utf-8') as f:
        content = f.read()

    old_vpn_func = """    func probableVPN() throws -> NetInfo? {
        try ensureReady()
        // TODO: @mahee96: we shouldn't return just the first coz user can have multiple uTUN lets revisit later to have a proper option
        return interfacesCache.first { $0.name.hasPrefix("utun") }
    }"""
    new_vpn_func = """    func probableVPN() throws -> NetInfo? {
        try ensureReady()
        // TODO: @mahee96: we shouldn't return just the first coz user can have multiple uTUN lets revisit later to have a proper option
        if let ifc = interfacesCache.first(where: { $0.hostIP == "10.7.0.0" }) {
            return ifc
        } else {
            return interfacesCache.first { $0.name.hasPrefix("utun") }
        }
    }"""

    if old_vpn_func in content:
        content = content.replace(old_vpn_func, new_vpn_func)
        with open(scanner_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("Successfully patched NetworkIfaceScanner.swift.")
    else:
        # Check normalized newlines/spacing just in case
        normalized_old = old_vpn_func.replace('\r\n', '\n')
        normalized_content = content.replace('\r\n', '\n')
        if normalized_old in normalized_content:
            normalized_content = normalized_content.replace(normalized_old, new_vpn_func.replace('\r\n', '\n'))
            with open(scanner_path, 'w', encoding='utf-8') as f:
                f.write(normalized_content)
            print("Successfully patched NetworkIfaceScanner.swift (with normalized newlines).")
        else:
            print("Warning: NetworkIfaceScanner.swift already patched or pattern not found.")

def main():
    patch_alt_sign()
    patch_minimuxer()

if __name__ == '__main__':
    main()
