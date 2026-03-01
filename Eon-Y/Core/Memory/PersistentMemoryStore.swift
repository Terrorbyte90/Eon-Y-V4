import Foundation
import SQLite3

// SQLITE_TRANSIENT är ett C-makro som Swift inte importerar direkt.
// Definieras som internal (ej private) så att actor-metoder kan nå den.
let SQLITE_TRANSIENT_FUNC = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// Säker helper: returnerar "" om sqlite3_column_text ger NULL (undviker EXC_BREAKPOINT)
private func sqlText(_ stmt: OpaquePointer?, _ col: Int32) -> String {
    guard let ptr = sqlite3_column_text(stmt, col) else { return "" }
    return String(cString: ptr)
}

// MARK: - PersistentMemoryStore: SQLite WAL med komplett schema

actor PersistentMemoryStore {
    static let shared = PersistentMemoryStore()

    private var db: OpaquePointer?
    private let dbPath: String

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dbPath = docs.appendingPathComponent("eon_v3.sqlite").path
        setupDatabase()
    }

    // MARK: - Schema setup

    private func setupDatabase() {
        // Försök öppna — om det misslyckas, försök med en in-memory databas som fallback
        var openResult = sqlite3_open(dbPath, &db)
        if openResult != SQLITE_OK {
            print("[Memory] Kunde inte öppna databas på disk (\(dbPath)): \(openResult) — försöker in-memory")
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
        print("[Memory] Databas initierad: \(dbPath)")
    }

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
        execute("CREATE INDEX IF NOT EXISTS idx_conv_session ON conversations(session_id)")
        execute("CREATE INDEX IF NOT EXISTS idx_conv_timestamp ON conversations(timestamp)")
        execute("CREATE INDEX IF NOT EXISTS idx_facts_subject ON facts(subject)")
        execute("CREATE INDEX IF NOT EXISTS idx_entities_name ON entities(name)")
        execute("CREATE INDEX IF NOT EXISTS idx_articles_domain ON articles(domain)")
        execute("CREATE INDEX IF NOT EXISTS idx_articles_created ON articles(created_at)")
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
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 2, role, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 3, content, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_double(stmt, 4, confidence)
            sqlite3_bind_text(stmt, 5, emotion, -1, SQLITE_TRANSIENT_FUNC)
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
            let safe = content.replacingOccurrences(of: "'", with: "''")
            execute("INSERT INTO conversations_fts(rowid, content) VALUES (\(rowId), '\(safe)')")
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
            sqlite3_bind_text(stmt, 1, query, -1, SQLITE_TRANSIENT_FUNC)
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
            sqlite3_bind_text(stmt, 1, subject, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 2, predicate, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 3, object, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_double(stmt, 4, confidence)
            if let src = source {
                sqlite3_bind_text(stmt, 5, src, -1, SQLITE_TRANSIENT_FUNC)
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
            sqlite3_bind_text(stmt, 1, subject, -1, SQLITE_TRANSIENT_FUNC)
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
            sqlite3_bind_text(stmt, 1, word, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 2, sense, -1, SQLITE_TRANSIENT_FUNC)
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
            sqlite3_bind_text(stmt, 1, word, -1, SQLITE_TRANSIENT_FUNC)
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

    // Räknar faktiska kunskapsnoder: fakta + artiklar
    func knowledgeNodeCount() -> Int {
        guard isReady else { return 0 }
        var factCount = 0
        var articleCount = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM facts", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { factCount = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        stmt = nil
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM articles", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { articleCount = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return factCount + articleCount * 10
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
            sqlite3_bind_text(stmt, 7, config, -1, SQLITE_TRANSIENT_FUNC)
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
                (id, title, content, summary, domain, source, is_autonomous, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        var success = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, article.id.uuidString, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 2, article.title, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 3, article.content, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 4, article.summary, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 5, article.domain, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 6, article.source, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_int(stmt, 7, article.isAutonomous ? 1 : 0)
            sqlite3_bind_double(stmt, 8, article.date.timeIntervalSince1970)
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
        let sql = "SELECT id, title, content, summary, domain, source, is_autonomous, created_at FROM articles ORDER BY created_at DESC LIMIT ?"
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
                    isAutonomous: sqlite3_column_int(stmt, 6) == 1
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func deleteArticle(title: String) {
        let safe = title.replacingOccurrences(of: "'", with: "''")
        execute("DELETE FROM articles WHERE title = '\(safe)'")
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

    func pruneOldFacts(olderThan days: Int, minConfidence: Double) {
        guard isReady else { return }
        let cutoff = Date().timeIntervalSince1970 - Double(days) * 86400
        let sql = "DELETE FROM facts WHERE created_at < ? AND confidence < ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, cutoff)
            sqlite3_bind_double(stmt, 2, minConfidence)
            if sqlite3_step(stmt) == SQLITE_DONE {
                let deleted = sqlite3_changes(db)
                if deleted > 0 { print("[Memory] Rensade \(deleted) gamla fakta") }
            }
        }
        sqlite3_finalize(stmt)
    }

    func recentArticleTitles(limit: Int = 200) -> [String] {
        loadAllArticles(limit: limit).map { $0.title }
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
        let sql = "SELECT id, title, content, summary, domain, source, is_autonomous, created_at FROM articles ORDER BY RANDOM() LIMIT ?"
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
                    isAutonomous: sqlite3_column_int(stmt, 6) == 1
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - Search facts by keyword

    func searchFacts(query: String, limit: Int = 5) -> [(subject: String, predicate: String, object: String)] {
        guard isReady, let db else { return [] }
        var results: [(String, String, String)] = []
        let keywords = Array(query.lowercased()
            .split(separator: " ")
            .filter { $0.count > 3 }
            .map(String.init)
            .prefix(3))
        guard !keywords.isEmpty else { return [] }

        let likeClause = keywords.map { _ in "(subject LIKE ? OR object LIKE ?)" }.joined(separator: " OR ")
        let sql = "SELECT subject, predicate, object FROM facts WHERE \(likeClause) ORDER BY confidence DESC LIMIT ?"
        // Bygg patterns som NSString för att garantera giltig C-sträng-livstid under hela bind-sekvensen
        let patterns: [NSString] = keywords.map { "%\($0)%" as NSString }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            if let errMsg = sqlite3_errmsg(db) {
                print("[Memory] searchFacts prepare fel: \(String(cString: errMsg))")
            }
            return []
        }

        var idx: Int32 = 1
        for pattern in patterns {
            sqlite3_bind_text(stmt, idx,     pattern.utf8String, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, idx + 1, pattern.utf8String, -1, SQLITE_TRANSIENT_FUNC)
            idx += 2
        }
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
            sqlite3_bind_text(stmt, 1, (domain as NSString).utf8String, -1, SQLITE_TRANSIENT_FUNC)
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return count
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
