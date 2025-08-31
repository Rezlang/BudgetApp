import Foundation
import LinkKit
import UIKit

final class PlaidService {
    static let shared = PlaidService()
    private init() {}

    private var handler: Handler?

    func linkAccount() {
        Task {
            do {
                let token = try await createLinkToken()
                await MainActor.run {
                    var configuration = LinkTokenConfiguration(token: token) { success in
                        Task { await self.exchangePublicToken(success.publicToken) }
                    }
                    configuration.onExit = { _ in }
                    self.handler = Plaid.create(configuration: configuration)
                    if let top = UIApplication.shared.topViewController() {
                        self.handler?.open(presentUsing: .viewController(top))
                    }
                }
            } catch {
                print("Plaid link error: \(error)")
            }
        }
    }

    private func createLinkToken() async throws -> String {
        guard let url = URL(string: "http://localhost:8000/api/plaid/create_link_token") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let token = json?["link_token"] as? String {
            return token
        } else {
            throw URLError(.badServerResponse)
        }
    }

    private func exchangePublicToken(_ publicToken: String) async {
        guard let url = URL(string: "http://localhost:8000/api/plaid/set_access_token") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["public_token": publicToken])
        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("Exchange public token failed: \(error)")
        }
    }
}

private extension UIApplication {
    func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(base: selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
