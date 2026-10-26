import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// ANISETTE_POLICY_SOURCE
// CERTIFICATE_POLICY_SOURCE
// REQUEST_POLICY_SOURCE

struct HeaderSection { var userAgent = "fallback"; var authApp = "com.apple.gs.xcode.auth" }
struct Headers { var grandSlam = HeaderSection(); var appleAuth = HeaderSection() }
struct AnisetteData {
    var clientInfo = AppleAnisetteLoginPolicy.macClientInfo
    var userAgent = AppleAnisetteLoginPolicy.macUserAgent
    var oneTimePassword = "test"; var machineID = "test"; var deviceID = "test"
    var localUserID = "test"; var routingInfo = "0"; var serialNumber = "test"
    var clientTime = "test"; var locale = "en_US"; var timeZone = "UTC"
}
struct TwoFactorAuthContext {
    var dsid = "test"; var idmsToken = "test"; var xcodeVersion = "26.0"
    var anisetteData = AnisetteData()
}
enum ServerError: Error { case badServerResponse(reason: String, jsonPayload: String) }
func debugLog(_ message: String) {}

final class FakeSession {
    var requests: [URLRequest] = []
    var statusCodes = [503, 200]
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let code = statusCodes.removeFirst()
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: code,
                                       httpVersion: "HTTP/1.1", headerFields: ["Retry-After": "0"])!)
    }
}
struct Requests {
    var customHeaders = Headers()
    let session = FakeSession()
    // TWO_FACTOR_FACTORY_SOURCE
    // LOGIN_REQUEST_SOURCE
    func run(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await performLoginRequest(request)
    }
    func gsaHeaders(_ anisetteData: AnisetteData) -> [String: String] {
        let h = customHeaders
        // GSA_HEADERS_SOURCE
        return headers
    }
    func phoneRequest(phone: String, mode: String) throws -> URLRequest {
        let sanitizedPhoneID = phone
        let requestedMode = mode
        let context = TwoFactorAuthContext()
        // PHONE_REQUEST_SOURCE
        return request
    }
    func trustedDeviceRequest() -> URLRequest {
        var request = makeTwoFactorAuthRequest(url: URL(string: "https://gsa.apple.com/auth/verify/trusteddevice")!, context: TwoFactorAuthContext())
        request.setValue("123456", forHTTPHeaderField: "security-code")
        return request
    }
}

@main struct AppleLoginTests {
    static func main() async throws {
        var checks = 0
        func check(_ predicate: Bool) { precondition(predicate); checks += 1 }
        for version in ["10.10.5", "10.11.6", "10.12.6"] {
            let identity = try AppleAnisetteLoginPolicy.identity(clientInfo: "<MacBookPro> <Mac OS X;\(version)>", userAgent: "old")
            check(identity.clientInfo == AppleAnisetteLoginPolicy.macClientInfo)
            check(identity.userAgent == AppleAnisetteLoginPolicy.macUserAgent)
        }
        let current = try AppleAnisetteLoginPolicy.identity(clientInfo: "<Mac15,7> <macOS;27.0;build>", userAgent: "MacAgent")
        check(current.clientInfo == "<Mac15,7> <macOS;27.0;build>")
        check(current.userAgent == "MacAgent")
        for invalid in ["", "<PC> <Windows;6.2>", "<Pixel 7> <Android;14>"] {
            do {
                _ = try AppleAnisetteLoginPolicy.identity(clientInfo: invalid, userAgent: "agent")
                fatalError("Non-Mac identity must not become Windows or be silently accepted")
            } catch { checks += 1 }
        }
        check(current.cacheKey(server: URL(string: "https://a.example")!) != current.cacheKey(server: URL(string: "https://b.example")!))
        let other = try AppleAnisetteLoginPolicy.identity(clientInfo: current.clientInfo, userAgent: "OtherAgent")
        check(current.cacheKey(server: URL(string: "https://a.example")!) != other.cacheKey(server: URL(string: "https://a.example")!))
        check(AppleAnisetteLoginPolicy.isLegacyIdentity("<Pixel 7> <Android;14>"))
        check(!AppleAnisetteLoginPolicy.isLegacyIdentity(current.clientInfo))

        check(SigningCertificateIdentity.preferredSerials(running: "AA", active: "BB", portal: ["aa", "bb"]) == ["AA", "BB"])
        check(SigningCertificateIdentity.preferredSerials(running: "REVOKED", active: "BB", portal: ["bb"]) == ["BB"])
        check(SigningCertificateIdentity.preferredSerials(running: "AA", active: "aa", portal: ["AA"]) == ["AA"])
        check(SigningCertificateIdentity.preferredSerials(running: "AA", active: nil, portal: []).isEmpty)
        check(!SigningCertificateIdentity.matches("", ""))
        check(!SigningCertificateIdentity.matches("AA", "BB"))

        for status in [200, 400, 401, 403, 500] {
            check(AppleLoginRequestPolicy.retryDelay(statusCode: status, attempt: 0, retryAfter: nil) == nil)
        }
        for status in [429, 503] {
            check(AppleLoginRequestPolicy.retryDelay(statusCode: status, attempt: 0, retryAfter: "0") == 0)
            check(AppleLoginRequestPolicy.retryDelay(statusCode: status, attempt: 2, retryAfter: nil) == nil)
            check(AppleLoginRequestPolicy.retryDelay(statusCode: status, attempt: 0, retryAfter: "60") == nil)
            check(AppleLoginRequestPolicy.retryDelay(statusCode: status, attempt: 0, retryAfter: "-1") == nil)
            check(AppleLoginRequestPolicy.retryDelay(statusCode: status, attempt: 0, retryAfter: "Wed, 21 Oct 2026 07:28:00 GMT") == nil)
        }
        let factory = Requests()
        let headers = factory.gsaHeaders(AnisetteData())
        check(headers["X-MMe-Client-Info"] == AppleAnisetteLoginPolicy.macClientInfo)
        check(headers["User-Agent"] == AppleAnisetteLoginPolicy.macUserAgent)
        let phone = try factory.phoneRequest(phone: "2", mode: "sms")
        check(phone.httpMethod == "PUT")
        check(phone.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONSerialization.jsonObject(with: phone.httpBody!) as! [String: Any]
        check((body["phoneNumber"] as? [String: Int])?["id"] == 2)
        for request in [phone, factory.trustedDeviceRequest()] {
            let executor = Requests()
            _ = try await executor.run(request)
            check(executor.session.requests.count == 2)
            for retry in executor.session.requests {
                check(retry.allHTTPHeaderFields == request.allHTTPHeaderFields)
                check(retry.httpBody == request.httpBody)
                check(retry.httpMethod == request.httpMethod)
                check(retry.url == request.url)
            }
        }
        let rejected = Requests()
        rejected.session.statusCodes = [403]
        _ = try await rejected.run(phone)
        check(rejected.session.requests.count == 1)
        print("Apple login/identity regression tests passed (\(checks) checks; no Apple authentication performed).")
    }
}
