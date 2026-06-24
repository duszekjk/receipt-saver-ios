import Foundation

struct BankImportJobStatus: Codable {
    let job_id: String
    let bank: String
    let status: String
    let progress_current: Int
    let progress_total: Int
    let created: Int
    let classified: Int
    let error_message: String
    let created_at: String?
    let started_at: String?
    let finished_at: String?
}
