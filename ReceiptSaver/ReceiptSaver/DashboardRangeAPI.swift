import Foundation

struct DashboardRangeRequest {
    var period: String
    var month: String = ""
    var startDate: Date? = nil
    var endDate: Date? = nil
    var averageMonths: Int? = nil
}

extension APIClient {
    func dashboard(range: DashboardRangeRequest, category: String, limit: Int) async throws -> DashboardStats {
        let url = baseURL.appendingPathComponent("dashboard/")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "period", value: range.period),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if range.period == "month", !range.month.isEmpty {
            items.append(URLQueryItem(name: "month", value: range.month))
        }
        if let startDate = range.startDate {
            items.append(URLQueryItem(name: "start_date", value: Self.dashboardDateFormatter.string(from: startDate)))
        }
        if let endDate = range.endDate {
            items.append(URLQueryItem(name: "end_date", value: Self.dashboardDateFormatter.string(from: endDate)))
        }
        if let averageMonths = range.averageMonths {
            items.append(URLQueryItem(name: "average_months", value: String(averageMonths)))
        }
        if !category.isEmpty {
            items.append(URLQueryItem(name: "category", value: category))
        }
        components.queryItems = items
        var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        let value = try await data(for: request)
        return try await Task.detached(priority: .userInitiated) {
            try JSONDecoder().decode(DashboardStats.self, from: value)
        }.value
    }

    func subcategoryDetails(range: DashboardRangeRequest, subcategory: String) async throws -> SubcategoryDetails {
        let url = baseURL.appendingPathComponent("dashboard/subcategory/")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "period", value: range.period),
            URLQueryItem(name: "subcategory", value: subcategory)
        ]
        if range.period == "month", !range.month.isEmpty {
            items.append(URLQueryItem(name: "month", value: range.month))
        }
        if let startDate = range.startDate {
            items.append(URLQueryItem(name: "start_date", value: Self.dashboardDateFormatter.string(from: startDate)))
        }
        if let endDate = range.endDate {
            items.append(URLQueryItem(name: "end_date", value: Self.dashboardDateFormatter.string(from: endDate)))
        }
        if let averageMonths = range.averageMonths {
            items.append(URLQueryItem(name: "average_months", value: String(averageMonths)))
        }
        components.queryItems = items
        var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        let value = try await data(for: request)
        return try await Task.detached(priority: .userInitiated) {
            try JSONDecoder().decode(SubcategoryDetails.self, from: value)
        }.value
    }

    private static let dashboardDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
