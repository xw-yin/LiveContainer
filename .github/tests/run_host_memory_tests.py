"""Compile the actual profile/signature guards with portable Swift fixtures."""
import pathlib
import subprocess
import sys
import tempfile


def between(source, start, end):
    assert source.count(start) == 1, f"Production test anchor changed: {start}"
    return source.split(start, 1)[1].split(end, 1)[0]


def main():
    sidestore = pathlib.Path(sys.argv[1]).resolve()
    fetch = (sidestore / "SideStore/Core/Operations/PipelineOperations/FetchProvisioningProfilesOperation.swift").read_text(encoding="utf-8")
    signer = (sidestore / "Dependencies/SideSign/Sources/CodeSigning/CodeSignerAPI.swift").read_text(encoding="utf-8")
    validator = "    private func validateHostMemoryProfile" + between(
        fetch, "    private func validateHostMemoryProfile", "    private func provisionAndFetchProfile")
    signing = "            let memoryKeys =" + between(
        signer, "            let memoryKeys =", '            verboseLog("[SideSign] Filtered entitlements')
    extension = "                let processMemory =" + between(
        signer, "                let processMemory =", "                try prepare(ext,")
    fixtures = pathlib.Path(__file__).with_name("HostMemoryProfileTests.swift").read_text(encoding="utf-8")
    fixtures = fixtures.replace("    // PROFILE_VALIDATOR_SOURCE", validator)
    fixtures = fixtures.replace("    // SIGNER_VALIDATOR_SOURCE", signing)
    fixtures = fixtures.replace("    // PROCESS_MEMORY_SOURCE", extension)
    with tempfile.TemporaryDirectory(prefix="host-memory-tests-") as directory:
        root = pathlib.Path(directory)
        source = root / "Tests.swift"
        source.write_text(fixtures, encoding="utf-8")
        binary = root / "tests"
        subprocess.run(["swiftc", "-swift-version", "5", "-parse-as-library", str(source), "-o", str(binary)], check=True)
        subprocess.run([str(binary)], check=True)


if __name__ == "__main__":
    main()
