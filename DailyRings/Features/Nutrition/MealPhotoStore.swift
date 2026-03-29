import UIKit
import Foundation

actor MealPhotoStore {
    private let fileManager = FileManager.default

    private var baseDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("meals", isDirectory: true)
    }

    // MARK: - Save

    func savePhoto(_ image: UIImage, for date: Date) async throws -> String {
        let dateDir = directoryForDate(date)
        try fileManager.createDirectory(at: dateDir, withIntermediateDirectories: true)

        let resized = resizeImage(image, maxDimension: AppConstants.mealPhotoMaxDimension)
        guard let data = resized.jpegData(compressionQuality: 0.8) else {
            throw PhotoStoreError.compressionFailed
        }

        let filename = "\(Int(Date.now.timeIntervalSince1970)).jpg"
        let fileURL = dateDir.appendingPathComponent(filename)
        try data.write(to: fileURL)

        let dateString = DateBoundary.dateString(from: date)
        return "\(dateString)/\(filename)"
    }

    // MARK: - Load

    func loadPhoto(filename: String) -> UIImage? {
        let url = baseDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadBase64(filename: String) -> String? {
        let url = baseDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return data.base64EncodedString()
    }

    func photosForDate(_ date: Date) -> [String] {
        let dateDir = directoryForDate(date)
        let dateString = DateBoundary.dateString(from: date)

        guard let files = try? fileManager.contentsOfDirectory(
            at: dateDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "jpg" }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            .map { "\(dateString)/\($0.lastPathComponent)" }
    }

    // MARK: - Cleanup

    func deleteExpiredPhotos(retentionDays: Int) throws {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: .now) ?? .now

        guard let dateDirs = try? fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for dir in dateDirs {
            guard let date = DateBoundary.date(from: dir.lastPathComponent) else { continue }
            if date < cutoff {
                try fileManager.removeItem(at: dir)
            }
        }
    }

    // MARK: - Helpers

    private func directoryForDate(_ date: Date) -> URL {
        let dateString = DateBoundary.dateString(from: date)
        return baseDirectory.appendingPathComponent(dateString, isDirectory: true)
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = max(size.width, size.height) / maxDimension
        guard ratio > 1 else { return image }

        let newSize = CGSize(width: size.width / ratio, height: size.height / ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    enum PhotoStoreError: Error, LocalizedError {
        case compressionFailed

        var errorDescription: String? {
            switch self {
            case .compressionFailed: return "Failed to compress photo"
            }
        }
    }
}
