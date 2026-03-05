import Foundation
import SQLite3

// SQLITE_TRANSIENT är ett C-makro som Swift inte importerar direkt.
let SQLITE_TRANSIENT_FUNC = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// Säker helper: returnerar "" om sqlite3_column_text ger NULL (undviker EXC_BREAKPOINT)
private func sqlText(_ stmt: OpaquePointer?, _ col: Int32) -> String {
    guard let ptr = sqlite3_column_text(stmt, col) else { return "" }
    return String(cString: ptr)
}

// Säker sqlite3_bind_text via NSString — garanterar giltig C-sträng-livstid
// under hela bind-anropet, oavsett Swift ARC-optimeringar.
@inline(__always)
private func bindText(_ stmt: OpaquePointer?, _ col: Int32, _ value: String) {
    (value as NSString).utf8String.map {
        sqlite3_bind_text(stmt, col, $0, -1, SQLITE_TRANSIENT_FUNC)
    }
}

// MARK: - PersistentMemoryStore: SQLite WAL med komplett schema

actor PersistentMemoryStore {
    static let shared = PersistentMemoryStore()

    private var db: OpaquePointer?
    private let dbPath: String

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let path = docs.appendingPathComponent("eon_v3.sqlite").path
        dbPath = path
        // Öppna databas direkt i init (actor init kan mutera egna stored properties)
        var openResult = sqlite3_open(path, &db)
        if openResult != SQLITE_OK {
            print("[Memory] Kunde inte öppna databas på disk (\(path)): \(openResult) — försöker in-memory")
            openResult = sqlite3_open(":memory:", &db)
        }
        guard openResult == SQLITE_OK, db != nil else {
            print("[Memory] KRITISKT: Kunde inte öppna databas alls")
            return
        }
        execute("PRAGMA journal_mode=WAL")
        execute("PRAGMA synchronous=NORMAL")
        execute("PRAGMA cache_size=-32000")
        execute("PRAGMA foreign_keys=ON")
        createTables()
        print("[Memory] Databas initierad: \(path)")
    }

    // MARK: - Schema setup

    // Returnerar true om databasen är redo att användas
    private var isReady: Bool { db != nil }

    private func createTables() {
        execute("""
            CREATE TABLE IF NOT EXISTS conversations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                embedding BLOB,
                confidence REAL DEFAULT 0.75,
                emotion TEXT DEFAULT 'neutral',
                timestamp REAL NOT NULL,
                importance REAL DEFAULT 0.5
            )
        """)
        execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS conversations_fts
            USING fts5(content, content='conversations', content_rowid='id', tokenize='unicode61')
        """)
        execute("""
            CREATE TABLE IF NOT EXISTS facts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subject TEXT NOT NULL,
                predicate TEXT NOT NULL,
                object TEXT NOT NULL,
                confidence REAL DEFAULT 0.7,
                source TEXT,
                valid_from REAL,
                valid_until REAL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
        """)
        execute("""
            CREATE TABLE IF NOT EXISTS entities (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                type TEXT NOT NULL,
                description TEXT,
                embedding BLOB,
                mention_count INTEGER DEFAULT 1,
                last_seen REAL NOT NULL
            )
        """)
        execute("""
            CREATE TABLE IF NOT EXISTS hnsw_nodes (
                id INTEGER PRIMARY KEY,
                layer INTEGER NOT NULL,
                neighbors TEXT NOT NULL,
                embedding BLOB NOT NULL,
                source_type TEXT NOT NULL,
                source_id INTEGER NOT NULL
            )
        """)
        execute("""
            CREATE TABLE IF NOT EXISTS fsrs_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                fact_id INTEGER REFERENCES facts(id),
                stability REAL DEFAULT 1.0,
                difficulty REAL DEFAULT 0.3,
                due_date REAL NOT NULL,
                review_count INTEGER DEFAULT 0,
                last_review REAL
            )
        """)
        execute("""
            CREATE TABLE IF NOT EXISTS beliefs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                statement TEXT UNIQUE NOT NULL,
                confidence REAL NOT NULL,
                evidence_count INTEGER DEFAULT 1,
                last_updated REAL NOT NULL
            )
        """)
        execute("""
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                started_at REAL NOT NULL,
                ended_at REAL,
                message_count INTEGER DEFAULT 0,
                dominant_emotion TEXT,
                summary TEXT
            )
        """)
        execute("""
            CREATE TABLE IF NOT EXISTS narrative_nodes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_type TEXT NOT NULL,
                description TEXT NOT NULL,
                emotional_weight REAL DEFAULT 0.5,
                timestamp REAL NOT NULL,
                related_facts TEXT
            )
        """)
        execute("""
            CREATE TABLE IF NOT EXISTS wsd_profile (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                word TEXT NOT NULL,
                preferred_sense TEXT NOT NULL,
                confidence REAL DEFAULT 0.8,
                occurrence_count INTEGER DEFAULT 1,
                last_seen REAL NOT NULL
            )
        """)
        execute("""
            CREATE TABLE IF NOT EXISTS eval_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                run_date REAL NOT NULL,
                correctness REAL,
                depth REAL,
                self_knowledge REAL,
                adaptivity REAL,
                lora_version INTEGER,
                config TEXT
            )
        """)
        execute("""
            CREATE TABLE IF NOT EXISTS articles (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                summary TEXT NOT NULL,
                domain TEXT NOT NULL,
                source TEXT NOT NULL DEFAULT '',
                is_autonomous INTEGER NOT NULL DEFAULT 1,
                created_at REAL NOT NULL
            )
        """)
        // Migration: lägg till eon_state_snapshot om kolumnen saknas
        execute("ALTER TABLE articles ADD COLUMN eon_state_snapshot TEXT NOT NULL DEFAULT ''")
        // Creative features — letters and awareness tests
        execute("""
            CREATE TABLE IF NOT EXISTS eon_letters (
                id TEXT PRIMARY KEY,
                sender TEXT NOT NULL,
                subject TEXT NOT NULL,
                body TEXT NOT NULL,
                is_read INTEGER NOT NULL DEFAULT 0,
                in_reply_to TEXT,
                created_at REAL NOT NULL
            )
        """)
        execute("""
            CREATE TABLE IF NOT EXISTS awareness_test_runs (
                id TEXT PRIMARY KEY,
                total_score REAL NOT NULL,
                passed_count INTEGER NOT NULL,
                results_json TEXT NOT NULL,
                created_at REAL NOT NULL
            )
        """)
        execute("CREATE INDEX IF NOT EXISTS idx_conv_session ON conversations(session_id)")
        execute("CREATE INDEX IF NOT EXISTS idx_conv_timestamp ON conversations(timestamp)")
        execute("CREATE INDEX IF NOT EXISTS idx_facts_subject ON facts(subject)")
        execute("CREATE INDEX IF NOT EXISTS idx_entities_name ON entities(name)")
        execute("CREATE INDEX IF NOT EXISTS idx_articles_domain ON articles(domain)")
        execute("CREATE INDEX IF NOT EXISTS idx_articles_created ON articles(created_at)")
        execute("CREATE INDEX IF NOT EXISTS idx_letters_created ON eon_letters(created_at)")
        execute("CREATE INDEX IF NOT EXISTS idx_awareness_created ON awareness_test_runs(created_at)")
    }

    // MARK: - Conversation operations

    @discardableResult
    func saveMessage(role: String, content: String, sessionId: String, confidence: Double = 0.75, emotion: String = "neutral") -> Bool {
        guard isReady else { return false }
        let sql = """
            INSERT INTO conversations (session_id, role, content, confidence, emotion, timestamp, importance)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bindText(stmt, 1, sessionId)
            bindText(stmt, 2, role)
            bindText(stmt, 3, content)
            sqlite3_bind_double(stmt, 4, confidence)
            bindText(stmt, 5, emotion)
            sqlite3_bind_double(stmt, 6, Date().timeIntervalSince1970)
            sqlite3_bind_double(stmt, 7, 0.5)
            success = sqlite3_step(stmt) == SQLITE_DONE
            if !success { print("[Memory] saveMessage fel: \(sqlText(nil, 0)) \(String(cString: sqlite3_errmsg(db)))") }
        } else {
            print("[Memory] saveMessage prepare fel: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        if success {
            let rowId = sqlite3_last_insert_rowid(db)
            // Parametriserad FTS-insert — undviker SQL-injection
            let ftsSql = "INSERT INTO conversations_fts(rowid, content) VALUES (?, ?)"
            var ftsStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, ftsSql, -1, &ftsStmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(ftsStmt, 1, rowId)
                bindText(ftsStmt, 2, content)
                if sqlite3_step(ftsStmt) != SQLITE_DONE {
                    print("[Memory] FTS insert fel: \(String(cString: sqlite3_errmsg(db)))")
                }
            }
            sqlite3_finalize(ftsStmt)
        }
        return success
    }

    func searchConversations(query: String, limit: Int = 10) -> [ConversationRecord] {
        guard isReady else { return [] }
        var results: [ConversationRecord] = []
        let sql = """
            SELECT c.id, c.role, c.content, c.timestamp, c.confidence, c.emotion
            FROM conversations c
            JOIN conversations_fts fts ON c.id = fts.rowid
            WHERE conversations_fts MATCH ?
            ORDER BY rank LIMIT ?
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bindText(stmt, 1, query)
            sqlite3_bind_int(stmt, 2, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(ConversationRecord(
                    id: Int(sqlite3_column_int(stmt, 0)),
                    role: sqlText(stmt, 1),
                    content: sqlText(stmt, 2),
                    timestamp: sqlite3_column_double(stmt, 3),
                    confidence: sqlite3_column_double(stmt, 4),
                    emotion: sqlText(stmt, 5)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func getRecentConversation(limit: Int = 8) -> [ConversationRecord] { recentConversations(limit: limit) }

    func recentConversations(limit: Int = 50) -> [ConversationRecord] {
        guard isReady else { return [] }
        var results: [ConversationRecord] = []
        let sql = "SELECT id, role, content, timestamp, confidence, emotion FROM conversations ORDER BY timestamp DESC LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(ConversationRecord(
                    id: Int(sqlite3_column_int(stmt, 0)),
                    role: sqlText(stmt, 1),
                    content: sqlText(stmt, 2),
                    timestamp: sqlite3_column_double(stmt, 3),
                    confidence: sqlite3_column_double(stmt, 4),
                    emotion: sqlText(stmt, 5)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results.reversed()
    }

    // MARK: - Knowledge graph operations

    @discardableResult
    func saveFact(subject: String, predicate: String, object: String, confidence: Double = 0.7, source: String? = nil) -> Bool {
        guard isReady else { return false }
        let sql = """
            INSERT OR REPLACE INTO facts (subject, predicate, object, confidence, source, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let now = Date().timeIntervalSince1970
            bindText(stmt, 1, subject)
            bindText(stmt, 2, predicate)
            bindText(stmt, 3, object)
            sqlite3_bind_double(stmt, 4, confidence)
            if let src = source {
                bindText(stmt, 5, src)
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            sqlite3_bind_double(stmt, 6, now)
            sqlite3_bind_double(stmt, 7, now)
            success = sqlite3_step(stmt) == SQLITE_DONE
            if !success { print("[Memory] saveFact fel (\(subject)/\(predicate)): \(String(cString: sqlite3_errmsg(db)))") }
        } else {
            print("[Memory] saveFact prepare fel: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        return success
    }

    func factsAbout(subject: String) -> [(predicate: String, object: String, confidence: Double)] {
        guard isReady else { return [] }
        var results: [(String, String, Double)] = []
        let sql = "SELECT predicate, object, confidence FROM facts WHERE subject = ? ORDER BY confidence DESC LIMIT 20"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bindText(stmt, 1, subject)
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append((sqlText(stmt, 0), sqlText(stmt, 1), sqlite3_column_double(stmt, 2)))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - WSD Profile

    func updateWSDProfile(word: String, sense: String) {
        guard isReady else { return }
        let sql = """
            INSERT INTO wsd_profile (word, preferred_sense, occurrence_count, last_seen)
            VALUES (?, ?, 1, ?)
            ON CONFLICT(word) DO UPDATE SET
                preferred_sense = CASE WHEN excluded.occurrence_count > occurrence_count THEN excluded.preferred_sense ELSE preferred_sense END,
                occurrence_count = occurrence_count + 1,
                last_seen = excluded.last_seen
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bindText(stmt, 1, word)
            bindText(stmt, 2, sense)
            sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
            if sqlite3_step(stmt) != SQLITE_DONE {
                print("[Memory] updateWSDProfile fel '\(word)': \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            print("[Memory] updateWSDProfile prepare fel: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
    }

    func preferredSense(for word: String) -> String? {
        guard isReady else { return nil }
        let sql = "SELECT preferred_sense FROM wsd_profile WHERE word = ? ORDER BY occurrence_count DESC LIMIT 1"
        var stmt: OpaquePointer?
        var result: String? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bindText(stmt, 1, word)
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = sqlText(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    // MARK: - Stats

    func conversationCount() -> Int {
        guard isReady else { return 0 }
        var count = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM conversations WHERE role = 'user'", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return count
    }

    // Antal fakta sparade sedan ett visst datum
    func factCountSince(_ date: Date) -> Int {
        guard isReady else { return 0 }
        var count = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM facts WHERE created_at >= ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970)
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return count
    }

    // Totalt antal ord i alla sparade konversationer (räknar content-kolumnen)
    func totalWordCount() -> Int {
        guard isReady else { return 0 }
        var count = 0
        var stmt: OpaquePointer?
        // Räknar mellanslag+1 per rad som approximation för ordantal
        let sql = "SELECT SUM(LENGTH(content) - LENGTH(REPLACE(content, ' ', '')) + 1) FROM conversations"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return max(0, count)
    }

    // Räknar faktiska kunskapsnoder: fakta + artiklar (en enda query)
    func knowledgeNodeCount() -> Int {
        guard isReady else { return 0 }
        var count = 0
        var stmt: OpaquePointer?
        let sql = "SELECT (SELECT COUNT(*) FROM facts) + (SELECT COUNT(*) FROM articles) * 10"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return count
    }

    @discardableResult
    func saveEvalResult(correctness: Double, depth: Double, selfKnowledge: Double, adaptivity: Double, loraVersion: Int, config: String) -> Bool {
        guard isReady else { return false }
        let sql = """
            INSERT INTO eval_results (run_date, correctness, depth, self_knowledge, adaptivity, lora_version, config)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
            sqlite3_bind_double(stmt, 2, correctness)
            sqlite3_bind_double(stmt, 3, depth)
            sqlite3_bind_double(stmt, 4, selfKnowledge)
            sqlite3_bind_double(stmt, 5, adaptivity)
            sqlite3_bind_int(stmt, 6, Int32(loraVersion))
            bindText(stmt, 7, config)
            success = sqlite3_step(stmt) == SQLITE_DONE
            if !success { print("[Memory] saveEvalResult fel: \(String(cString: sqlite3_errmsg(db)))") }
        } else {
            print("[Memory] saveEvalResult prepare fel: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        return success
    }

    func recentEvalResults(limit: Int = 14) -> [EvalResult] {
        guard isReady else { return [] }
        var results: [EvalResult] = []
        let sql = "SELECT run_date, correctness, depth, self_knowledge, adaptivity, lora_version FROM eval_results ORDER BY run_date DESC LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(EvalResult(
                    date: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0)),
                    correctness: sqlite3_column_double(stmt, 1),
                    depth: sqlite3_column_double(stmt, 2),
                    selfKnowledge: sqlite3_column_double(stmt, 3),
                    adaptivity: sqlite3_column_double(stmt, 4),
                    loraVersion: Int(sqlite3_column_int(stmt, 5))
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - Article operations

    @discardableResult
    func saveArticle(_ article: KnowledgeArticle) -> Bool {
        guard isReady else { return false }
        let sql = """
            INSERT OR REPLACE INTO articles
                (id, title, content, summary, domain, source, is_autonomous, created_at, eon_state_snapshot)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bindText(stmt, 1, article.id.uuidString)
            bindText(stmt, 2, article.title)
            bindText(stmt, 3, article.content)
            bindText(stmt, 4, article.summary)
            bindText(stmt, 5, article.domain)
            bindText(stmt, 6, article.source)
            sqlite3_bind_int(stmt, 7, article.isAutonomous ? 1 : 0)
            sqlite3_bind_double(stmt, 8, article.date.timeIntervalSince1970)
            bindText(stmt, 9, article.eonStateSnapshot)
            success = sqlite3_step(stmt) == SQLITE_DONE
            if !success { print("[Memory] saveArticle fel '\(article.title)': \(String(cString: sqlite3_errmsg(db)))") }
        } else {
            print("[Memory] saveArticle prepare fel: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        return success
    }

    func loadAllArticles(limit: Int = 500) -> [KnowledgeArticle] {
        guard isReady else { return [] }
        var results: [KnowledgeArticle] = []
        let sql = "SELECT id, title, content, summary, domain, source, is_autonomous, created_at, eon_state_snapshot FROM articles ORDER BY created_at DESC LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let uuid = UUID(uuidString: sqlText(stmt, 0)) ?? UUID()
                results.append(KnowledgeArticle(
                    id: uuid,
                    title: sqlText(stmt, 1),
                    content: sqlText(stmt, 2),
                    summary: sqlText(stmt, 3),
                    domain: sqlText(stmt, 4),
                    source: sqlText(stmt, 5),
                    date: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7)),
                    isAutonomous: sqlite3_column_int(stmt, 6) == 1,
                    eonStateSnapshot: sqlText(stmt, 8)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func deleteArticle(title: String) {
        guard isReady else { return }
        let sql = "DELETE FROM articles WHERE title = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bindText(stmt, 1, title)
            if sqlite3_step(stmt) != SQLITE_DONE {
                print("[Memory] deleteArticle fel: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        sqlite3_finalize(stmt)
    }

    func articleCount() -> Int {
        guard isReady else { return 0 }
        var count = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM articles", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return count
    }

    func factCount() -> Int {
        guard isReady else { return 0 }
        var count = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM facts", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return count
    }

    /// Deprioritizes old low-confidence facts by halving their confidence.
    /// Memory is NEVER deleted — only deprioritized so it fades naturally in retrieval ranking.
    func deprioritizeOldFacts(olderThan days: Int, belowConfidence: Double) {
        guard isReady else { return }
        let cutoff = Date().timeIntervalSince1970 - Double(days) * 86400
        let sql = "UPDATE facts SET confidence = confidence * 0.5, updated_at = ? WHERE created_at < ? AND confidence < ? AND confidence > 0.01"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
            sqlite3_bind_double(stmt, 2, cutoff)
            sqlite3_bind_double(stmt, 3, belowConfidence)
            if sqlite3_step(stmt) == SQLITE_DONE {
                let changed = sqlite3_changes(db)
                if changed > 0 { print("[Memory] Deprioriterade \(changed) gamla fakta (confidence halverad)") }
            }
        }
        sqlite3_finalize(stmt)
    }

    @available(*, deprecated, renamed: "deprioritizeOldFacts")
    func pruneOldFacts(olderThan days: Int, minConfidence: Double) {
        deprioritizeOldFacts(olderThan: days, belowConfidence: minConfidence)
    }

    func recentArticleTitles(limit: Int = 200) -> [String] {
        guard isReady else { return [] }
        var results: [String] = []
        let sql = "SELECT title FROM articles ORDER BY created_at DESC LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(sqlText(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func recentUserMessages(limit: Int = 10) -> [String] {
        guard isReady else { return [] }
        var results: [String] = []
        let sql = "SELECT content FROM conversations WHERE role = 'user' ORDER BY timestamp DESC LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(sqlText(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func randomArticles(limit: Int = 3) -> [KnowledgeArticle] {
        guard isReady else { return [] }
        var results: [KnowledgeArticle] = []
        let sql = "SELECT id, title, content, summary, domain, source, is_autonomous, created_at, eon_state_snapshot FROM articles ORDER BY RANDOM() LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let uuid = UUID(uuidString: sqlText(stmt, 0)) ?? UUID()
                results.append(KnowledgeArticle(
                    id: uuid,
                    title: sqlText(stmt, 1),
                    content: sqlText(stmt, 2),
                    summary: sqlText(stmt, 3),
                    domain: sqlText(stmt, 4),
                    source: sqlText(stmt, 5),
                    date: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7)),
                    isAutonomous: sqlite3_column_int(stmt, 6) == 1,
                    eonStateSnapshot: sqlText(stmt, 8)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - Search facts by keyword (v12: improved — lower char threshold, more keywords, also searches predicate)

    func searchFacts(query: String, limit: Int = 5) -> [(subject: String, predicate: String, object: String)] {
        guard isReady, let db else { return [] }
        var results: [(String, String, String)] = []
        // v12: Lower threshold from >3 to >2 chars, allow up to 5 keywords
        let keywords = Array(query.lowercased()
            .split(separator: " ")
            .filter { $0.count > 2 }
            .map(String.init)
            .prefix(5))
        guard !keywords.isEmpty else { return [] }

        // v12: Also search predicate field + search for the full query as exact match on subject
        let likeClause = keywords.map { _ in "(subject LIKE ? OR object LIKE ? OR predicate LIKE ?)" }.joined(separator: " OR ")
        let sql = "SELECT subject, predicate, object FROM facts WHERE (\(likeClause)) OR subject LIKE ? ORDER BY confidence DESC LIMIT ?"
        let patterns: [String] = keywords.map { "%\($0)%" }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            if let errMsg = sqlite3_errmsg(db) {
                print("[Memory] searchFacts prepare fel: \(String(cString: errMsg))")
            }
            return []
        }

        var idx: Int32 = 1
        for pattern in patterns {
            bindText(stmt, idx,     pattern)  // subject
            bindText(stmt, idx + 1, pattern)  // object
            bindText(stmt, idx + 2, pattern)  // predicate
            idx += 3
        }
        // Exact subject match for the full query
        bindText(stmt, idx, "%\(query.lowercased())%")
        idx += 1
        sqlite3_bind_int(stmt, idx, Int32(limit))

        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append((sqlText(stmt, 0), sqlText(stmt, 1), sqlText(stmt, 2)))
        }
        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - Recent facts

    func recentFacts(limit: Int = 10) -> [(subject: String, predicate: String, object: String)] {
        guard isReady else { return [] }
        var results: [(String, String, String)] = []
        let sql = "SELECT subject, predicate, object FROM facts ORDER BY created_at DESC LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append((sqlText(stmt, 0), sqlText(stmt, 1), sqlText(stmt, 2)))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func recentFactsWithConfidence(limit: Int = 50) -> [(subject: String, predicate: String, object: String, confidence: Double)] {
        guard isReady else { return [] }
        var results: [(String, String, String, Double)] = []
        let sql = "SELECT subject, predicate, object, confidence FROM facts ORDER BY created_at DESC LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let conf = sqlite3_column_double(stmt, 3)
                results.append((sqlText(stmt, 0), sqlText(stmt, 1), sqlText(stmt, 2), conf))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func articleCountForDomain(_ domain: String) -> Int {
        guard isReady else { return 0 }
        var count = 0
        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*) FROM articles WHERE domain = ?"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bindText(stmt, 1, domain)
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return count
    }

    // MARK: - Random facts (used by SleepConsolidationEngine for REM replay)

    func randomFacts(limit: Int = 4) -> [(subject: String, predicate: String, object: String, confidence: Double)] {
        guard isReady else { return [] }
        var results: [(String, String, String, Double)] = []
        let sql = "SELECT subject, predicate, object, confidence FROM facts ORDER BY RANDOM() LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append((
                    sqlText(stmt, 0),
                    sqlText(stmt, 1),
                    sqlText(stmt, 2),
                    sqlite3_column_double(stmt, 3)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - Memory Consolidation
    // Periodically merges duplicate facts, strengthens frequently accessed facts,
    // and creates summary facts from clusters of related facts.

    func consolidateMemories() async {
        guard isReady else { return }

        // 1. Merge exact duplicate facts — keep the one with highest confidence
        mergeDuplicateFacts()

        // 2. Strengthen frequently accessed/high-evidence facts
        strengthenStrongFacts()

        // 3. Deprioritize old low-confidence facts (never delete)
        deprioritizeOldFacts(olderThan: 30, belowConfidence: 0.2)

        // 4. Create summary facts from clusters of related facts (same subject)
        await createSummaryFacts()

        print("[Memory] Konsolidering klar")
    }

    private func mergeDuplicateFacts() {
        guard isReady else { return }
        // Find duplicates: same subject+predicate+object, keep highest confidence
        let findSql = """
            SELECT subject, predicate, object, MAX(confidence) as max_conf, COUNT(*) as cnt
            FROM facts
            GROUP BY subject, predicate, object
            HAVING cnt > 1
        """
        var stmt: OpaquePointer?
        var duplicates: [(String, String, String, Double)] = []
        if sqlite3_prepare_v2(db, findSql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                duplicates.append((
                    sqlText(stmt, 0),
                    sqlText(stmt, 1),
                    sqlText(stmt, 2),
                    sqlite3_column_double(stmt, 3)
                ))
            }
        }
        sqlite3_finalize(stmt)

        for (subj, pred, obj, maxConf) in duplicates {
            // Keep the row with highest confidence, deprioritize others
            let updateSql = """
                UPDATE facts SET confidence = confidence * 0.1
                WHERE subject = ? AND predicate = ? AND object = ?
                AND confidence < ?
            """
            var updateStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, updateSql, -1, &updateStmt, nil) == SQLITE_OK {
                bindText(updateStmt, 1, subj)
                bindText(updateStmt, 2, pred)
                bindText(updateStmt, 3, obj)
                sqlite3_bind_double(updateStmt, 4, maxConf)
                _ = sqlite3_step(updateStmt)
            }
            sqlite3_finalize(updateStmt)
        }

        if !duplicates.isEmpty {
            print("[Memory] Sammanfogade \(duplicates.count) duplicerade faktakluster")
        }
    }

    private func strengthenStrongFacts() {
        guard isReady else { return }
        // Facts with high confidence that are recent get a small boost
        let sql = """
            UPDATE facts SET confidence = MIN(0.99, confidence * 1.02), updated_at = ?
            WHERE confidence > 0.7
            AND updated_at > ?
        """
        var stmt: OpaquePointer?
        let now = Date().timeIntervalSince1970
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, now)
            sqlite3_bind_double(stmt, 2, now - 86400 * 7) // Active in last 7 days
            _ = sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    private func createSummaryFacts() async {
        guard isReady else { return }
        // Find subjects with many facts (>5) that don't already have summaries
        let sql = """
            SELECT subject, COUNT(*) as cnt FROM facts
            WHERE predicate != 'sammanfattar' AND predicate != 'konsoliderad_sammanfattning'
            GROUP BY subject HAVING cnt > 5
            ORDER BY cnt DESC LIMIT 5
        """
        var stmt: OpaquePointer?
        var subjects: [(String, Int)] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                subjects.append((sqlText(stmt, 0), Int(sqlite3_column_int(stmt, 1))))
            }
        }
        sqlite3_finalize(stmt)

        for (subject, _) in subjects {
            let existingSummary = factsAbout(subject: subject).first { $0.predicate == "konsoliderad_sammanfattning" }
            guard existingSummary == nil else { continue }

            let facts = factsAbout(subject: subject)
            let factStr = facts.prefix(8).map { "\($0.predicate): \($0.object)" }.joined(separator: "; ")
            let summaryText = "Sammanfattat: \(subject) — \(String(factStr.prefix(200)))"

            saveFact(
                subject: subject,
                predicate: "konsoliderad_sammanfattning",
                object: summaryText,
                confidence: 0.8,
                source: "consolidation"
            )
        }
    }

    // MARK: - Strengthen a specific fact (called on retrieval to implement "use it or lose it")

    func strengthenFact(subject: String, predicate: String) {
        guard isReady else { return }
        let sql = "UPDATE facts SET confidence = MIN(0.99, confidence * 1.05), updated_at = ? WHERE subject = ? AND predicate = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
            bindText(stmt, 2, subject)
            bindText(stmt, 3, predicate)
            _ = sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Helper

    @discardableResult
    private func execute(_ sql: String) -> Bool {
        guard db != nil else { return false }
        var errMsg: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if result != SQLITE_OK, let msg = errMsg {
            print("[Memory] SQL fel: \(String(cString: msg))")
            sqlite3_free(errMsg)
            return false
        }
        return true
    }

    // MARK: - Public parameterised helpers for creative features

    @discardableResult
    func execute(_ sql: String, params: [Any]) -> Bool {
        guard db != nil else { return false }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        for (i, param) in params.enumerated() {
            let idx = Int32(i + 1)
            switch param {
            case let v as String: bindText(stmt, idx, v)
            case let v as Int:    sqlite3_bind_int64(stmt, idx, Int64(v))
            case let v as Double: sqlite3_bind_double(stmt, idx, v)
            default:              bindText(stmt, idx, "\(param)")
            }
        }
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        return rc == SQLITE_DONE || rc == SQLITE_ROW
    }

    func query(_ sql: String, params: [Any] = []) -> [[Any]] {
        guard db != nil else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        for (i, param) in params.enumerated() {
            let idx = Int32(i + 1)
            switch param {
            case let v as String: bindText(stmt, idx, v)
            case let v as Int:    sqlite3_bind_int64(stmt, idx, Int64(v))
            case let v as Double: sqlite3_bind_double(stmt, idx, v)
            default:              bindText(stmt, idx, "\(param)")
            }
        }
        var rows: [[Any]] = []
        let colCount = sqlite3_column_count(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [Any] = []
            for col in 0..<colCount {
                switch sqlite3_column_type(stmt, col) {
                case SQLITE_INTEGER: row.append(Int(sqlite3_column_int64(stmt, col)))
                case SQLITE_FLOAT:   row.append(sqlite3_column_double(stmt, col))
                case SQLITE_TEXT:    row.append(String(cString: sqlite3_column_text(stmt, col)))
                case SQLITE_NULL:    row.append("")
                default:             row.append("")
                }
            }
            rows.append(row)
        }
        sqlite3_finalize(stmt)
        return rows
    }
}

// MARK: - Data models

struct ConversationRecord: Identifiable {
    let id: Int
    let role: String
    let content: String
    let timestamp: Double
    let confidence: Double
    let emotion: String

    var date: Date { Date(timeIntervalSince1970: timestamp) }
    var isUser: Bool { role == "user" }
}

struct EvalResult: Identifiable {
    let id = UUID()
    let date: Date
    let correctness: Double
    let depth: Double
    let selfKnowledge: Double
    let adaptivity: Double
    let loraVersion: Int

    var average: Double { (correctness + depth + selfKnowledge + adaptivity) / 4.0 }
}
