import Foundation
import SwiftUI

// MARK: - AppConfiguration
// Centraliserade UserDefaults-nycklar och standardvärden.
// Alla delar av appen ska använda dessa konstanter istället för råa strängar.

enum AppKeys {

    // MARK: Eon-identitet
    static let name                 = "eon_name"
    static let personality          = "eon_personality"
    static let cognitiveMode        = "eon_cognitive_mode"

    // MARK: Kognitiva funktioner
    static let loop1Enabled         = "eon_loop1"
    static let loop3Enabled         = "eon_loop3"
    static let caiEnabled           = "eon_cai"
    static let cotEnabled           = "eon_cot"
    static let saveHistory          = "eon_save_history"
    static let episodicEnabled      = "eon_episodic"
    static let knowledgeGraph       = "eon_knowledge_graph"
    static let nightlyConsolidation = "eon_nightly"
    static let loraTraining         = "eon_lora"
    static let aeroEnabled          = "eon_aero"
    static let evalEnabled          = "eon_eval"
    static let rollbackEnabled      = "eon_rollback"
    static let sprakbankenSync      = "eon_sprakbanken"
    static let thoughtGlass         = "eon_thoughtglass"
    static let showConfidence       = "eon_confidence"
    static let devMode              = "eon_dev_mode"
    static let motorControl         = "eon_motor_control"

    // MARK: Proaktivitet
    static let proactiveEnabled     = "eon_proactive"
    static let proactiveInterval    = "eon_proactive_interval"

    // MARK: Artiklar
    static let articlesPerInterval  = "eon_articles_per_interval"
    static let articleIntervalMins  = "eon_article_interval_minutes"

    // MARK: Modell-hantering
    static let bertAutoUnload       = "eon_bert_auto_unload"
    static let gptAutoUnload        = "eon_gpt_auto_unload"
    static let restExtraPct         = "eon_rest_extra_pct"

    // MARK: Automations-faser (sekunder)
    static let phaseDurationInt     = "eon_phase_duration_inte"
    static let phaseDurationLearn   = "eon_phase_duration_inlä"
    static let phaseDurationLang    = "eon_phase_duration_språ"
    static let phaseDurationRest    = "eon_phase_duration_vila"

    // MARK: Automations-uppgifter
    static let autoHypothesis       = "eon_auto_hypothesis"
    static let autoReasoning        = "eon_auto_reasoning"
    static let autoWorldModel       = "eon_auto_worldmodel"
    static let autoLanguageExp      = "eon_auto_language_exp"
    static let autoSprakbanken      = "eon_auto_sprakbanken"
    static let autoConsolidation    = "eon_auto_consolidation"
    static let autoSelfReflect      = "eon_auto_selfreflect"
    static let autoArticles         = "eon_auto_articles"
}

// MARK: - AppDefaults
// Standardvärden för alla inställningar — en enda källa till sanning.

enum AppDefaults {
    static let name                 = "Eon"
    static let personality          = "Standard"
    static let cognitiveMode        = "Djup"
    static let proactiveInterval    = "Dag"
    static let articlesPerInterval  = 1
    static let articleIntervalMins  = 60
    static let restExtraPct         = 50
    static let phaseDurationInt     = 40
    static let phaseDurationLearn   = 30
    static let phaseDurationLang    = 25
    static let phaseDurationRest    = 25
}

// MARK: - AppConfiguration
// Hjälpklass för att läsa/skriva konfiguration med typsäkerhet.

final class AppConfiguration {

    static let shared = AppConfiguration()
    private init() {}

    // Autonomi-uppgifter
    var isHypothesisEnabled:   Bool { bool(AppKeys.autoHypothesis,    default: true) }
    var isReasoningEnabled:    Bool { bool(AppKeys.autoReasoning,     default: true) }
    var isWorldModelEnabled:   Bool { bool(AppKeys.autoWorldModel,    default: true) }
    var isLanguageExpEnabled:  Bool { bool(AppKeys.autoLanguageExp,   default: true) }
    var isSprakbankenEnabled:  Bool { bool(AppKeys.autoSprakbanken,   default: true) }
    var isConsolidationEnabled:Bool { bool(AppKeys.autoConsolidation, default: true) }
    var isSelfReflectEnabled:  Bool { bool(AppKeys.autoSelfReflect,   default: true) }
    var isArticlesEnabled:     Bool { bool(AppKeys.autoArticles,      default: true) }

    // Modell-hantering
    var bertAutoUnload: Bool { bool(AppKeys.bertAutoUnload, default: true) }
    var gptAutoUnload:  Bool { bool(AppKeys.gptAutoUnload,  default: true) }
    var restExtraPct:   Int  { int(AppKeys.restExtraPct,    default: AppDefaults.restExtraPct) }

    // Fas-durationer
    var phaseDurationInt:   Int { int(AppKeys.phaseDurationInt,   default: AppDefaults.phaseDurationInt) }
    var phaseDurationLearn: Int { int(AppKeys.phaseDurationLearn, default: AppDefaults.phaseDurationLearn) }
    var phaseDurationLang:  Int { int(AppKeys.phaseDurationLang,  default: AppDefaults.phaseDurationLang) }
    var phaseDurationRest:  Int { int(AppKeys.phaseDurationRest,  default: AppDefaults.phaseDurationRest) }

    // MARK: - Privata helpers

    private func bool(_ key: String, default defaultValue: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }

    private func int(_ key: String, default defaultValue: Int) -> Int {
        UserDefaults.standard.object(forKey: key) as? Int ?? defaultValue
    }

    private func string(_ key: String, default defaultValue: String) -> String {
        UserDefaults.standard.string(forKey: key) ?? defaultValue
    }
}
