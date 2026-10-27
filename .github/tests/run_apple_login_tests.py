"""Exercise actual login policies/request builders without credentials or network."""
import pathlib
import subprocess
import sys
import tempfile


def section(text, start, end):
    assert text.count(start) == 1, start
    assert end in text.split(start, 1)[1], end
    return text.split(start, 1)[1].split(end, 1)[0]


def main():
    root = pathlib.Path(sys.argv[1]).resolve()
    provider = (root / "SideStore/Core/Anisette/AnisetteProvider.swift").read_text(encoding="utf-8")
    certificate = (root / "SideStore/Core/Certificates/CertificateManager.swift").read_text(encoding="utf-8")
    auth = (root / "Dependencies/SideSign/Sources/DeveloperPortal/Authentication.swift").read_text(encoding="utf-8")
    replacements = {
        "ANISETTE_POLICY_SOURCE": section(provider, "// BEGIN APPLE ANISETTE LOGIN POLICY", "// END APPLE ANISETTE LOGIN POLICY"),
        "CERTIFICATE_POLICY_SOURCE": section(certificate, "// BEGIN SIGNING CERTIFICATE IDENTITY POLICY", "// END SIGNING CERTIFICATE IDENTITY POLICY"),
        "REQUEST_POLICY_SOURCE": section(auth, "// BEGIN APPLE LOGIN REQUEST POLICY", "// END APPLE LOGIN REQUEST POLICY"),
        "TWO_FACTOR_FACTORY_SOURCE": "    private func makeTwoFactorAuthRequest" + section(auth, "    private func makeTwoFactorAuthRequest", "    // Retries the original request"),
        "LOGIN_REQUEST_SOURCE": "    private func performLoginRequest" + section(auth, "    private func performLoginRequest", "    private func parsePlistOrJSON"),
        "GSA_HEADERS_SOURCE": "        let userAgent =" + section(auth, "        let userAgent =", "        headers.forEach"),
        "PHONE_REQUEST_SOURCE": "        guard let targetPhoneID =" + section(auth, "        guard let targetPhoneID =", "        if let allHeaders = request.allHTTPHeaderFields"),
    }
    fixture = pathlib.Path(__file__).with_name("AppleLoginTests.swift").read_text(encoding="utf-8")
    for marker, source in replacements.items():
        fixture = fixture.replace("// " + marker, source)
    with tempfile.TemporaryDirectory(prefix="apple-login-tests-") as directory:
        source = pathlib.Path(directory) / "Tests.swift"
        executable = pathlib.Path(directory) / "tests"
        source.write_text(fixture, encoding="utf-8")
        subprocess.run(["swiftc", "-swift-version", "5", "-parse-as-library", str(source), "-o", str(executable)], check=True)
        subprocess.run([str(executable)], check=True)


if __name__ == "__main__":
    main()
