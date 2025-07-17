import Foundation
import SwiftData

class DataExporter {
    
    // ワークアウトデータをCSV形式にエクスポート
    static func exportWorkoutsToCSV(sessions: [WorkoutSession]) -> String {
        var csvContent = ""
        
        // CSVヘッダー
        csvContent += "日付,時刻,ワークアウト時間(分),部位,種目,セット番号,重量(kg),回数,メモ,セッションメモ\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ja_JP")
        timeFormatter.dateFormat = "HH:mm:ss"
        
        // 各セッションをCSV行に変換
        for session in sessions.sorted(by: { $0.date > $1.date }) {
            let sessionDate = dateFormatter.string(from: session.date)
            let sessionTime = timeFormatter.string(from: session.date)
            let sessionDuration = String(format: "%.1f", session.duration / 60.0)
            let sessionNotes = escapeCSVField(session.notes)
            
            if session.exercises.isEmpty {
                // エクササイズがない場合もセッション情報だけ記録
                csvContent += "\(sessionDate),\(sessionTime),\(sessionDuration),,,,,,\(sessionNotes)\n"
            } else {
                for exercise in session.exercises {
                    let bodyPart = exercise.bodyPart.displayName
                    let exerciseName = escapeCSVField(exercise.name)
                    
                    if exercise.sets.isEmpty {
                        // セットがない場合
                        csvContent += "\(sessionDate),\(sessionTime),\(sessionDuration),\(bodyPart),\(exerciseName),0,0,0,,\(sessionNotes)\n"
                    } else {
                        for (index, set) in exercise.sets.enumerated() {
                            let setNumber = index + 1
                            let weight = String(format: "%.1f", set.weight)
                            let reps = set.reps
                            let setMemo = escapeCSVField(set.memo)
                            
                            csvContent += "\(sessionDate),\(sessionTime),\(sessionDuration),\(bodyPart),\(exerciseName),\(setNumber),\(weight),\(reps),\(setMemo),\(sessionNotes)\n"
                        }
                    }
                }
            }
        }
        
        return csvContent
    }
    
    // 統計データをCSV形式にエクスポート
    static func exportStatsToCSV(sessions: [WorkoutSession]) -> String {
        var csvContent = ""
        
        // CSVヘッダー
        csvContent += "日付,総ボリューム(kg),総セット数,総エクササイズ数,トレーニング部位数,ワークアウト時間(分),セッションメモ\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 日付別に統計を集計
        let sessionsByDate = Dictionary(grouping: sessions) { session in
            Calendar.current.startOfDay(for: session.date)
        }
        
        for (date, sessionsOnDate) in sessionsByDate.sorted(by: { $0.key > $1.key }) {
            let dateString = dateFormatter.string(from: date)
            
            let totalVolume = sessionsOnDate.reduce(0) { $0 + $1.totalVolume }
            let totalSets = sessionsOnDate.reduce(0) { $0 + $1.totalSets }
            let totalExercises = sessionsOnDate.reduce(0) { $0 + $1.exercises.count }
            let trainedBodyParts = Set(sessionsOnDate.flatMap { $0.trainedBodyParts })
            let totalDuration = sessionsOnDate.reduce(0) { $0 + $1.duration }
            let allNotes = sessionsOnDate.map { $0.notes }.filter { !$0.isEmpty }.joined(separator: "; ")
            
            let volumeString = String(format: "%.1f", totalVolume)
            let durationString = String(format: "%.1f", totalDuration / 60.0)
            let notesString = escapeCSVField(allNotes)
            
            csvContent += "\(dateString),\(volumeString),\(totalSets),\(totalExercises),\(trainedBodyParts.count),\(durationString),\(notesString)\n"
        }
        
        return csvContent
    }
    
    // 部位別統計をCSV形式にエクスポート
    static func exportBodyPartStatsToCSV(sessions: [WorkoutSession]) -> String {
        var csvContent = ""
        
        // CSVヘッダー
        csvContent += "部位,総トレーニング回数,総ボリューム(kg),総セット数,平均セット数,最後のトレーニング日\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 部位別に統計を集計
        var bodyPartStats: [BodyPart: (count: Int, volume: Double, sets: Int, lastDate: Date)] = [:]
        
        for session in sessions {
            for exercise in session.exercises {
                let bodyPart = exercise.bodyPart
                let volume = exercise.totalVolume
                let sets = exercise.sets.count
                
                if var stats = bodyPartStats[bodyPart] {
                    stats.count += 1
                    stats.volume += volume
                    stats.sets += sets
                    if session.date > stats.lastDate {
                        stats.lastDate = session.date
                    }
                    bodyPartStats[bodyPart] = stats
                } else {
                    bodyPartStats[bodyPart] = (count: 1, volume: volume, sets: sets, lastDate: session.date)
                }
            }
        }
        
        // 部位順にCSV行を作成
        for bodyPart in BodyPart.allCases {
            if let stats = bodyPartStats[bodyPart] {
                let bodyPartName = bodyPart.displayName
                let count = stats.count
                let volume = String(format: "%.1f", stats.volume)
                let totalSets = stats.sets
                let avgSets = String(format: "%.1f", Double(stats.sets) / Double(stats.count))
                let lastDate = dateFormatter.string(from: stats.lastDate)
                
                csvContent += "\(bodyPartName),\(count),\(volume),\(totalSets),\(avgSets),\(lastDate)\n"
            } else {
                let bodyPartName = bodyPart.displayName
                csvContent += "\(bodyPartName),0,0.0,0,0.0,-\n"
            }
        }
        
        return csvContent
    }
    
    // CSV用のフィールドエスケープ処理
    private static func escapeCSVField(_ field: String) -> String {
        let trimmedField = field.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedField.contains(",") || trimmedField.contains("\"") || trimmedField.contains("\n") {
            let escapedField = trimmedField.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedField)\""
        }
        return trimmedField
    }
    
    // ファイル名生成
    static func generateFileName(prefix: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        return "\(prefix)_\(timestamp).csv"
    }
    
    // MARK: - Import Functions
    
    // CSVファイルからワークアウトデータをインポート
    static func importWorkoutsFromCSV(csvContent: String) -> Result<ImportResult, ImportError> {
        let lines = csvContent.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            return .failure(.invalidFormat("CSVファイルが空または無効です"))
        }
        
        // ヘッダーをチェック
        let header = lines[0]
        let expectedHeaders = ["日付", "時刻", "ワークアウト時間(分)", "部位", "種目", "セット番号", "重量(kg)", "回数", "メモ", "セッションメモ"]
        
        if !isValidHeader(header, expectedHeaders: expectedHeaders) {
            return .failure(.invalidFormat("CSVヘッダーが期待される形式と一致しません"))
        }
        
        var importedSessions: [WorkoutSession] = []
        var sessionDict: [String: WorkoutSession] = [:]
        var exerciseDict: [String: Exercise] = [:]
        var errors: [String] = []
        var processedCount = 0
        var skippedCount = 0
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.locale = Locale(identifier: "ja_JP")
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        
        for (index, line) in lines.enumerated() {
            guard index > 0, !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            
            let fields = parseCSVLine(line)
            guard fields.count >= 10 else {
                errors.append("行 \(index + 1): フィールド数が不足しています")
                skippedCount += 1
                continue
            }
            
            do {
                // 日付と時刻を解析
                let dateString = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let timeString = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let combinedDateString = "\(dateString) \(timeString)"
                
                guard let sessionDate = dateFormatter.date(from: combinedDateString) else {
                    errors.append("行 \(index + 1): 日付形式が無効です (\(combinedDateString))")
                    skippedCount += 1
                    continue
                }
                
                // セッションキー（日付+時刻で一意識別）
                let sessionKey = combinedDateString
                
                // セッションを取得または作成
                var session: WorkoutSession
                if let existingSession = sessionDict[sessionKey] {
                    session = existingSession
                } else {
                    session = WorkoutSession(date: sessionDate)
                    
                    // ワークアウト時間を設定
                    if let durationMinutes = Double(fields[2]), durationMinutes > 0 {
                        session.duration = durationMinutes * 60 // 秒に変換
                    }
                    
                    // セッションメモを設定
                    let sessionNotes = unescapeCSVField(fields[9])
                    if !sessionNotes.isEmpty {
                        session.notes = sessionNotes
                    }
                    
                    sessionDict[sessionKey] = session
                    importedSessions.append(session)
                }
                
                // エクササイズ情報を処理
                let bodyPartString = fields[3].trimmingCharacters(in: .whitespacesAndNewlines)
                let exerciseName = unescapeCSVField(fields[4]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !bodyPartString.isEmpty && !exerciseName.isEmpty {
                    guard let bodyPart = BodyPart.allCases.first(where: { $0.displayName == bodyPartString }) else {
                        errors.append("行 \(index + 1): 未知の部位です (\(bodyPartString))")
                        skippedCount += 1
                        continue
                    }
                    
                    // エクササイズキー
                    let exerciseKey = "\(sessionKey)_\(bodyPartString)_\(exerciseName)"
                    
                    // エクササイズを取得または作成
                    var exercise: Exercise
                    if let existingExercise = exerciseDict[exerciseKey] {
                        exercise = existingExercise
                    } else {
                        exercise = Exercise(name: exerciseName, bodyPart: bodyPart)
                        exerciseDict[exerciseKey] = exercise
                        session.addExercise(exercise)
                    }
                    
                    // セット情報を追加
                    let setNumber = Int(fields[5]) ?? 0
                    if setNumber > 0 {
                        let weight = Double(fields[6]) ?? 0.0
                        let reps = Int(fields[7]) ?? 0
                        let setMemo = unescapeCSVField(fields[8])
                        
                        exercise.addSet(weight: weight, reps: reps, memo: setMemo)
                    }
                }
                
                processedCount += 1
                
            } catch {
                errors.append("行 \(index + 1): \(error.localizedDescription)")
                skippedCount += 1
            }
        }
        
        let result = ImportResult(
            importedSessions: importedSessions,
            processedCount: processedCount,
            skippedCount: skippedCount,
            errors: errors
        )
        
        return .success(result)
    }
    
    // ヘッダーの妥当性をチェック
    private static func isValidHeader(_ header: String, expectedHeaders: [String]) -> Bool {
        let actualHeaders = parseCSVLine(header)
        guard actualHeaders.count >= expectedHeaders.count else { return false }
        
        for (index, expected) in expectedHeaders.enumerated() {
            if index < actualHeaders.count {
                let actual = actualHeaders[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if actual != expected {
                    return false
                }
            }
        }
        return true
    }
    
    // CSV行をパース（カンマ区切り、引用符対応）
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                if insideQuotes {
                    // 次の文字も引用符かチェック（エスケープされた引用符）
                    let nextIndex = line.index(after: i)
                    if nextIndex < line.endIndex && line[nextIndex] == "\"" {
                        currentField += "\""
                        i = line.index(after: nextIndex)
                        continue
                    } else {
                        insideQuotes = false
                    }
                } else {
                    insideQuotes = true
                }
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField += String(char)
            }
            
            i = line.index(after: i)
        }
        
        // 最後のフィールドを追加
        fields.append(currentField)
        
        return fields
    }
    
    // CSV用のフィールドアンエスケープ処理
    private static func unescapeCSVField(_ field: String) -> String {
        let trimmedField = field.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedField.hasPrefix("\"") && trimmedField.hasSuffix("\"") {
            let unquoted = String(trimmedField.dropFirst().dropLast())
            return unquoted.replacingOccurrences(of: "\"\"", with: "\"")
        }
        return trimmedField
    }
}

// MARK: - Import Types

struct ImportResult {
    let importedSessions: [WorkoutSession]
    let processedCount: Int
    let skippedCount: Int
    let errors: [String]
    
    var successCount: Int {
        return importedSessions.count
    }
    
    var hasErrors: Bool {
        return !errors.isEmpty
    }
}

enum ImportError: Error, LocalizedError {
    case invalidFormat(String)
    case parseError(String)
    case duplicateData(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let message):
            return "フォーマットエラー: \(message)"
        case .parseError(let message):
            return "解析エラー: \(message)"
        case .duplicateData(let message):
            return "重複データ: \(message)"
        }
    }
} 