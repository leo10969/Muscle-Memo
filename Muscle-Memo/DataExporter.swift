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
} 