import Foundation
import Combine

struct ExchangeRateResponse: Decodable {
    let amount: Double?
    let base: String
    let date: String
    let rates: [String: Double]
}

struct ExchangeRateResult {
    let baseCurrency: AppCurrency
    let targetCurrency: AppCurrency
    let rate: Double
    let dateString: String
}

enum ExchangeRateServiceError: LocalizedError {
    case invalidURL
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid exchange rate URL."
        case .invalidResponse:
            return "Invalid exchange rate response."
        }
    }
}

final class ExchangeRateService {
    func fetchLatestRate(from base: AppCurrency, to target: AppCurrency) async throws -> ExchangeRateResult {
        if base == target {
            return ExchangeRateResult(
                baseCurrency: base,
                targetCurrency: target,
                rate: 1,
                dateString: ISO8601DateFormatter().string(from: Date())
            )
        }

        let urlString = "https://api.frankfurter.dev/v1/latest?base=\(base.rawValue)&symbols=\(target.rawValue)"
        guard let url = URL(string: urlString) else {
            throw ExchangeRateServiceError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)

        guard let rate = decoded.rates[target.rawValue] else {
            throw ExchangeRateServiceError.invalidResponse
        }

        return ExchangeRateResult(
            baseCurrency: base,
            targetCurrency: target,
            rate: rate,
            dateString: decoded.date
        )
    }
}

@MainActor
final class ExchangeRateViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var rateDescription = "-"
    @Published var sampleDescription = "-"
    @Published var lastUpdated = "-"
    @Published var errorMessage: String?
    
    private let service = ExchangeRateService()
    
    func refresh(base: AppCurrency, target: AppCurrency, settings: AppSettings) async {
        isLoading = true
        errorMessage = nil
        
        if !base.isSupportedByExchangeAPI {
            rateDescription = "-"
            sampleDescription = "-"
            lastUpdated = "-"
            errorMessage = settings.tr("exchange.unavailableMessage", base.rawValue)
            isLoading = false
            return
        }
        
        do {
            let result = try await service.fetchLatestRate(from: base, to: target)
            
            let rateValue = result.rate.asCurrency(
                code: target.rawValue,
                locale: settings.appLocale,
                minimumFractionDigits: 2,
                maximumFractionDigits: 4
            )
            
            let sampleValue = (100 * result.rate).asCurrency(
                code: target.rawValue,
                locale: settings.appLocale,
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            )
            
            rateDescription = "1 \(result.baseCurrency.rawValue) = \(rateValue)"
            sampleDescription = "100 \(result.baseCurrency.rawValue) = \(sampleValue)"
            lastUpdated = result.dateString
        } catch {
            rateDescription = "-"
            sampleDescription = "-"
            lastUpdated = "-"
            errorMessage = settings.t("exchange.error")
        }
        
        isLoading = false
    }
}
