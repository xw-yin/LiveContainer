"""Check real Mach-O dependencies against the production clone removal policy."""
import pathlib
import plistlib
import re
import struct
import sys
import tempfile
import zipfile


def dependencies(binary):
    data = binary.read_bytes()
    if data[:4] != b"\xcf\xfa\xed\xfe":
        return []  # Device builds use a thin arm64 image.
    count = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    result = []
    for _ in range(count):
        command, size = struct.unpack_from("<II", data, offset)
        if size < 8 or offset + size > len(data):
            raise ValueError(f"Invalid Mach-O command in {binary}")
        if command in (0xC, 0x8000001F, 0x80000023):  # Strong load/reexport/upward
            name_offset = struct.unpack_from("<I", data, offset + 8)[0]
            result.append(data[offset + name_offset:offset + size].split(b"\0", 1)[0].decode())
        offset += size
    return result


def verify(app, source):
    app = pathlib.Path(app)
    if app.suffix == ".ipa":
        with tempfile.TemporaryDirectory(prefix="ipa-runtime-") as directory:
            with zipfile.ZipFile(app) as archive:
                archive.extractall(directory)
            apps = list((pathlib.Path(directory) / "Payload").glob("*.app"))
            if len(apps) != 1:
                raise ValueError("Expected one application in IPA Payload")
            return verify(apps[0], source)
    text = pathlib.Path(source).read_text(encoding="utf-8")
    method = text.split("+ (NSURL *)archiveIPAWithBundleName:", 1)[1]
    removed = re.findall(r'removeItemUnlockingAtURL:\[appBundlePath URLByAppendingPathComponent:@"([^"]+)"\]', method)
    frameworks = app / "Frameworks"
    owned = {p.name for p in frameworks.glob("*.framework")}
    info = plistlib.loads((app / "Info.plist").read_bytes())
    images = [app / info["CFBundleExecutable"]]
    images += [p / p.stem for p in frameworks.glob("*.framework") if (p / p.stem).is_file()]
    checked = 0
    for image in images:
        relative = image.relative_to(app).as_posix()
        if any(relative == item or relative.startswith(item + "/") for item in removed):
            continue
        for dependency in dependencies(image):
            if not dependency.startswith("@rpath/"):
                continue
            suffix = dependency[len("@rpath/"):]
            framework = suffix.split("/", 1)[0]
            required_host = {"LiveContainerShared.framework", "LiveContainerSwiftUI.framework", "SideStoreSupport.framework", "MultitaskSupport.framework"}
            if framework not in owned and framework not in required_host:
                continue
            target = "Frameworks/" + suffix
            if any(target == item or target.startswith(item + "/") for item in removed):
                raise ValueError(f"Clone removes required dependency {dependency} loaded by {relative}")
            if not (app / target).is_file():
                raise ValueError(f"Required clone dependency is missing: {dependency}")
            checked += 1
    return checked


def self_test():
    def image(dependency=None):
        command = b""
        if dependency:
            name = dependency.encode() + b"\0"
            size = (24 + len(name) + 7) // 8 * 8
            command = struct.pack("<IIIIII", 0xC, size, 24, 0, 0, 0) + name
            command += b"\0" * (size - len(command))
        return struct.pack("<IIIIIIII", 0xFEEDFACF, 0x100000C, 0, 6, bool(command), len(command), 0, 0) + command
    with tempfile.TemporaryDirectory(prefix="clone-runtime-") as folder:
        root = pathlib.Path(folder)
        app = root / "App.app"
        ui = app / "Frameworks/LiveContainerSwiftUI.framework/LiveContainerSwiftUI"
        support = app / "Frameworks/SideStoreSupport.framework/SideStoreSupport"
        support.parent.mkdir(parents=True)
        ui.parent.mkdir(parents=True)
        (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": "App"}))
        (app / "App").write_bytes(image())
        ui.write_bytes(image("@rpath/SideStoreSupport.framework/SideStoreSupport"))
        support.write_bytes(image())
        source = root / "LCUtils.m"
        prefix = "+ (NSURL *)archiveIPAWithBundleName:"
        source.write_text(prefix, encoding="utf-8")
        assert verify(app, source) == 1
        source.write_text(prefix + '[LCSharedUtils removeItemUnlockingAtURL:[appBundlePath URLByAppendingPathComponent:@"Frameworks/SideStoreSupport.framework"] error:nil];', encoding="utf-8")
        try:
            verify(app, source)
        except ValueError:
            pass
        else:
            raise AssertionError("The original clone regression must be detected")
        source.write_text(prefix, encoding="utf-8")
        support.unlink()
        try:
            verify(app, source)
        except ValueError:
            pass
        else:
            raise AssertionError("A packaged IPA missing the support framework must fail")
    print("Clone runtime dependency regression checks passed.")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    else:
        count = verify(sys.argv[1], sys.argv[2])
        print(f"Clone runtime dependencies verified ({count} bundled strong dependencies).")
