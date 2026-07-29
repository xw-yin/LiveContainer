import os

def main():
    path = 'SideStoreBuild/Dependencies/AltSign/Package.swift'
    if not os.path.exists(path):
        print(f"Error: {path} not found.")
        return

    with open(path, 'r', encoding='utf-8') as f:
        lines = f.read().splitlines()

    modified = False
    for i, line in enumerate(lines):
        if 'name: "NativeBridge"' in line:
            # The next non-empty line should be dependencies: [
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

if __name__ == '__main__':
    main()
