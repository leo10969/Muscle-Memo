//
//  Item.swift
//  Muscle-Memo
//
//  Created by rsato on 2025/07/16.
//

import Foundation
import SwiftData
import SwiftUI

// 筋肉部位の列挙型
enum BodyPart: String, CaseIterable, Codable {
    case chest = "胸"
    case arms = "腕"
    case shoulders = "肩"
    case back = "背中"
    case legs = "脚"
    case abs = "腹"
    case glutes = "お尻"
    case cardio = "有酸素運動"
    
    var displayName: String {
        return self.rawValue
    }
    
    // 必須部位かどうか
    var isRequired: Bool {
        switch self {
        case .chest, .arms, .shoulders, .back, .legs:
            return true
        case .abs, .glutes, .cardio:
            return false
        }
    }
    
    // 必須部位のみを取得
    static var requiredParts: [BodyPart] {
        return allCases.filter { $0.isRequired }
    }
    
    // オプション部位のみを取得
    static var optionalParts: [BodyPart] {
        return allCases.filter { !$0.isRequired }
    }
    
    // 各部位のテーマカラー
    var color: Color {
        switch self {
        case .chest:
            return .red
        case .arms:
            return .blue
        case .shoulders:
            return .orange
        case .back:
            return .green
        case .legs:
            return .purple
        case .abs:
            return .yellow
        case .glutes:
            return .pink
        case .cardio:
            return .cyan
        }
    }
    
    // 各部位の主要種目（デフォルト表示用）
    var primaryExercises: [String] {
        switch self {
        case .chest:
            return ["ベンチプレス", "ダンベルベンチプレス", "インクラインベンチプレス", "プッシュアップ（腕立て伏せ）", "ディップス"]
        case .arms:
            return ["バーベルカール", "ダンベルカール", "ハンマーカール", "トライセプスプレスダウン", "フレンチプレス"]
        case .shoulders:
            return ["ショルダープレス", "サイドレイズ", "フロントレイズ", "リアレイズ", "ラテラルレイズ"]
        case .back:
            return ["チンニング", "プルアップ", "ラットプルダウン", "ベントオーバーローイング", "デッドリフト"]
        case .legs:
            return ["スクワット", "レッグプレス", "レッグカール", "レッグエクステンション", "カーフレイズ"]
        case .abs:
            return ["クランチ", "プランク", "シットアップ", "レッグレイズ", "ロシアンツイスト"]
        case .glutes:
            return ["ヒップスラスト", "ブルガリアンスクワット", "ワイドスクワット", "デッドリフト", "ヒップエクステンション"]
        case .cardio:
            return ["ランニング", "ウォーキング", "サイクリング", "ローイングマシン", "エリプティカル"]
        }
    }
    
    // 各部位の代表的なエクササイズ（全種目）
    var defaultExercises: [String] {
        switch self {
        case .chest:
            return [
                "ベンチプレス", "ダンベルベンチプレス", "インクラインベンチプレス", 
                "デクラインベンチプレス", "ナローグリップベンチプレス", "ワイドグリップベンチプレス",
                "ダンベルフライ", "インクラインダンベルフライ", "インクラインダンベルベンチプレス",
                "プッシュアップ（腕立て伏せ）", "ディップス", "チェストフライ", 
                "ペクトラルフライ", "ケーブルフライ", "プルオーバー"
            ]
        case .arms:
            return [
                // 上腕二頭筋
                "バーベルカール", "ダンベルカール", "ハンマーカール", 
                "インクラインダンベルカール", "コンセントレーションカール", "プリーチャーカール",
                "バックハンドカール", "ケーブルカール", "21カール",
                // 上腕三頭筋
                "トライセプスプレスダウン", "オーバーヘッドトライセプスエクステンション",
                "トライセプスキックバック", "ライイングトライセプスエクステンション",
                "ダイアモンドプッシュアップ", "ディップス", "フレンチプレス",
                "クローズグリップベンチプレス", "トライセプスディップス"
            ]
        case .shoulders:
            return [
                "ショルダープレス", "フロントプレス", "バックプレス", 
                "ダンベルショルダープレス", "サイドレイズ", "フロントレイズ", "リアレイズ",
                "ラテラルレイズ", "アップライトローイング", "シュラッグ", 
                "ベントオーバーラテラルレイズ", "ケーブルサイドレイズ", "フェイスプル",
                "アーノルドプレス", "パイクプッシュアップ"
            ]
        case .back:
            return [
                // 背中上部
                "チンニング", "プルアップ", "ラットプルダウン", "インクラインチンニング",
                "ワンハンドダンベルローイング", "ベントオーバーローイング", "ケーブルローイング",
                "シーテッドローイング", "Tバーローイング", "プルオーバー",
                // 背中下部・脊柱起立筋
                "デッドリフト", "ルーマニアンデッドリフト", "バックエクステンション", 
                "バックレイズ", "ボディーアーチ", "グッドモーニング", "ハイパーエクステンション"
            ]
        case .legs:
            return [
                // 大腿四頭筋・臀筋
                "スクワット", "フロントスクワット", "ナロースタンススクワット", 
                "ワイドスタンススクワット", "ゴブレットスクワット", "ブルガリアンスクワット",
                "シシースクワット", "ヒンズースクワット", "シングルレッグスクワット",
                "レッグプレス", "レッグエクステンション", "ハックスクワット",
                // ハムストリングス・臀筋
                "レッグカール", "ルーマニアンデッドリフト", "スティッフレッグデッドリフト",
                "ヒップスラスト", "ヒップリフト", "グルートブリッジ",
                // ランジ系
                "フロントランジ", "サイドランジ", "リバースランジ", "ウォーキングランジ",
                // ふくらはぎ
                "カーフレイズ", "シングルレッグカーフレイズ", "ドンキーカーフレイズ",
                "シーテッドカーフレイズ"
            ]
        case .abs:
            return [
                "クランチ", "ツイストクランチ", "サイドクランチ", "リバースクランチ",
                "シットアップ", "ツイストシットアップ", "Vシット", "ロシアンツイスト",
                "レッグレイズ", "ハンギングレッグレイズ", "ニートゥチェスト", 
                "ヒップレイズ", "ヒップスラスト", "マウンテンクライマー",
                "プランク", "サイドプランク", "プランクアップダウン",
                "ドラゴンフラッグ", "サイドベンド", "デッドバグ", "バードドッグ",
                "ホローボディホールド", "シザーズ", "バイシクルクランチ", "トランクカール"
            ]
        case .glutes:
            return [
                "ヒップスラスト", "バーベルヒップスラスト", "ダンベルヒップスラスト",
                "グルートブリッジ", "シングルレッググルートブリッジ", "ヒップリフト",
                "ブルガリアンスクワット", "リバースランジ", "サイドランジ",
                "ワイドスクワット", "スモウスクワット", "ゴブレットスクワット",
                "デッドリフト", "ルーマニアンデッドリフト", "スティッフレッグデッドリフト",
                "ヒップエクステンション", "リバースハイパーエクステンション",
                "クラムシェル", "ファイアーハイドラント", "ドンキーキック",
                "サイドステップ", "ラテラルウォーク", "モンスターウォーク"
            ]
        case .cardio:
            return [
                "ランニング", "ジョギング", "ウォーキング", "トレッドミル",
                "サイクリング", "エアロバイク", "スピンバイク", "リカンベントバイク",
                "ローイングマシン", "エリプティカル", "クロストレーナー",
                "ステップマシン", "ステアクライマー", "ジャンプロープ",
                "バーピー", "マウンテンクライマー", "ハイニー", "バットキック",
                "ジャンピングジャック", "プライオメトリック", "HIITトレーニング",
                "サーキットトレーニング", "タバタ", "スプリント", "インターバルランニング"
            ]
        }
    }
}

// セット情報
@Model
final class ExerciseSet {
    var weight: Double
    var reps: Int
    var memo: String
    var createdAt: Date
    
    init(weight: Double, reps: Int, memo: String = "") {
        self.weight = weight
        self.reps = reps
        self.memo = memo
        self.createdAt = Date()
    }
}

// エクササイズ情報
@Model
final class Exercise {
    var name: String
    var bodyPart: BodyPart
    var sets: [ExerciseSet]
    var createdAt: Date
    
    init(name: String, bodyPart: BodyPart) {
        self.name = name
        self.bodyPart = bodyPart
        self.sets = []
        self.createdAt = Date()
    }
    
    func addSet(weight: Double, reps: Int, memo: String = "") {
        let newSet = ExerciseSet(weight: weight, reps: reps, memo: memo)
        sets.append(newSet)
    }
    
    var totalVolume: Double {
        return sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
}

// ワークアウトセッション
@Model
final class WorkoutSession: Identifiable {
    var date: Date
    var exercises: [Exercise]
    var notes: String
    var duration: TimeInterval // 秒単位
    
    init(date: Date = Date()) {
        self.date = date
        self.exercises = []
        self.notes = ""
        self.duration = 0
    }
    
    func addExercise(_ exercise: Exercise) {
        exercises.append(exercise)
    }
    
    func removeExercise(_ exercise: Exercise) {
        exercises.removeAll { $0.name == exercise.name && $0.bodyPart == exercise.bodyPart }
    }
    
    var trainedBodyParts: Set<BodyPart> {
        return Set(exercises.map { $0.bodyPart })
    }
    
    var totalVolume: Double {
        return exercises.reduce(0) { $0 + $1.totalVolume }
    }
    
    var totalSets: Int {
        return exercises.reduce(0) { $0 + $1.sets.count }
    }
}

// 下位互換性のため（既存のコードで使用されている場合）
typealias Item = WorkoutSession
