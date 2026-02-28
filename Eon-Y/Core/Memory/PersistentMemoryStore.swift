import Foundation
import SQLite3

// SQLITE_TRANSIENT är ett C-makro som Swift inte importerar direkt
private let SQLITE_TRANSIENT_FUNC = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            print("[Memory] Kunde inte öppna databas")
            return
        }

        // WAL-läge för bättre concurrent performance
        execute("PRAGMA journal_mode=WAL")
        execute("PRAGMA synchronous=NORMAL")
        execute("PRAGMA cache_size=-32000") // 32MB cache
        execute("PRAGMA foreign_keys=ON")

        createTables()
        print("[Memory] Databas initierad: \(dbPath)")
    }

    private func createTables() {
        // Konversationer
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

        // FTS5 för fulltext-sökning
        execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS conversations_fts
            USING fts5(content, content='conversations', content_rowid='id', tokenize='unicode61')
        """)

        // Fakta/entiteter i kunskapsgrafen
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

        // Entiteter
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

        // HNSW-noder för vektorsökning
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

        // FSRS spaced repetition
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

        // Beliefs (Bayesiansk trosrevision)
        execute("""
            CREATE TABLE IF NOT EXISTS beliefs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                statement TEXT UNIQUE NOT NULL,
                confidence REAL NOT NULL,
                evidence_count INTEGER DEFAULT 1,
                last_updated REAL NOT NULL
            )
        """)

        // Sessioner
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

        // Narrativa noder (Eons livsberättelse om användaren)
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

        // WSD-profil (Pelare F: disambigueringsprofil per användare)
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

        // Eon-Eval resultat
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

        // Index för performance
        execute("CREATE INDEX IF NOT EXISTS idx_conv_session ON conversations(session_id)")
        execute("CREATE INDEX IF NOT EXISTS idx_conv_timestamp ON conversations(timestamp)")
        execute("CREATE INDEX IF NOT EXISTS idx_facts_subject ON facts(subject)")
        execute("CREATE INDEX IF NOT EXISTS idx_entities_name ON entities(name)")
    }

    // MARK: - Conversation operations

    func saveMessage(role: String, content: String, sessionId: String, confidence: Double = 0.75, emotion: String = "neutral") {
        let sql = """
            INSERT INTO conversations (session_id, role, content, confidence, emotion, timestamp, importance)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 2, role, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 3, content, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_double(stmt, 4, confidence)
            sqlite3_bind_text(stmt, 5, emotion, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_double(stmt, 6, Date().timeIntervalSince1970)
            sqlite3_bind_double(stmt, 7, 0.5)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        // Uppdatera FTS
        let rowId = sqlite3_last_insert_rowid(db)
        execute("INSERT INTO conversations_fts(rowid, content) VALUES (\(rowId), '\(content.replacingOccurrences(of: "'", with: "''"))')")
    }

    func searchConversations(query: String, limit: Int = 10) -> [ConversationRecord] {
        var results: [ConversationRecord] = []
        let sql = """
            SELECT c.id, c.role, c.content, c.timestamp, c.confidence, c.emotion
            FROM conversations c
            JOIN conversations_fts fts ON c.id = fts.rowid
            WHERE conversations_fts MATCH ?
            ORDER BY rank
            LIMIT ?
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, query, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_int(stmt, 2, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let record = ConversationRecord(
                    id: Int(sqlite3_column_int(stmt, 0)),
                    role: String(cString: sqlite3_column_text(stmt, 1)),
                    content: String(cString: sqlite3_column_text(stmt, 2)),
                    timestamp: sqlite3_column_double(stmt, 3),
                    confidence: sqlite3_column_double(stmt, 4),
                    emotion: String(cString: sqlite3_column_text(stmt, 5))
                )
                results.append(record)
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func getRecentConversation(limit: Int = 8) -> [ConversationRecord] {
        recentConversations(limit: limit)
    }

    func recentConversations(limit: Int = 50) -> [ConversationRecord] {
        var results: [ConversationRecord] = []
        let sql = "SELECT id, role, content, timestamp, confidence, emotion FROM conversations ORDER BY timestamp DESC LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(ConversationRecord(
                    id: Int(sqlite3_column_int(stmt, 0)),
                    role: String(cString: sqlite3_column_text(stmt, 1)),
                    content: String(cString: sqlite3_column_text(stmt, 2)),
                    timestamp: sqlite3_column_double(stmt, 3),
                    confidence: sqlite3_column_double(stmt, 4),
                    emotion: String(cString: sqlite3_column_text(stmt, 5))
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results.reversed()
    }

    // MARK: - Knowledge graph operations

    func saveFact(subject: String, predicate: String, object: String, confidence: Double = 0.7, source: String? = nil) {
        let sql = """
            INSERT OR REPLACE INTO facts (subject, predicate, object, confidence, source, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let now = Date().timeIntervalSince1970
            sqlite3_bind_text(stmt, 1, subject, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 2, predicate, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 3, object, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_double(stmt, 4, confidence)
            if let source = source {
                sqlite3_bind_text(stmt, 5, source, -1, SQLITE_TRANSIENT_FUNC)
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            sqlite3_bind_double(stmt, 6, now)
            sqlite3_bind_double(stmt, 7, now)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func factsAbout(subject: String) -> [(predicate: String, object: String, confidence: Double)] {
        var results: [(String, String, Double)] = []
        let sql = "SELECT predicate, object, confidence FROM facts WHERE subject = ? ORDER BY confidence DESC LIMIT 20"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, subject, -1, SQLITE_TRANSIENT_FUNC)
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append((
                    String(cString: sqlite3_column_text(stmt, 0)),
                    String(cString: sqlite3_column_text(stmt, 1)),
                    sqlite3_column_double(stmt, 2)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - WSD Profile

    func updateWSDProfile(word: String, sense: String) {
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
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func preferredSense(for word: String) -> String? {
        let sql = "SELECT preferred_sense FROM wsd_profile WHERE word = ? ORDER BY occurrence_count DESC LIMIT 1"
        var stmt: OpaquePointer?
        var result: String? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, word, -1, SQLITE_TRANSIENT_FUNC)
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = String(cString: sqlite3_column_text(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    // MARK: - Stats

    func conversationCount() -> Int {
        var count = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM conversations WHERE role = 'user'", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return count
    }

    func knowledgeNodeCount() -> Int {
        var count = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM entities", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return count
    }

    func saveEvalResult(correctness: Double, depth: Double, selfKnowledge: Double, adaptivity: Double, loraVersion: Int, config: String) {
        let sql = """
            INSERT INTO eval_results (run_date, correctness, depth, self_knowledge, adaptivity, lora_version, config)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
            sqlite3_bind_double(stmt, 2, correctness)
            sqlite3_bind_double(stmt, 3, depth)
            sqlite3_bind_double(stmt, 4, selfKnowledge)
            sqlite3_bind_double(stmt, 5, adaptivity)
            sqlite3_bind_int(stmt, 6, Int32(loraVersion))
            sqlite3_bind_text(stmt, 7, config, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func recentEvalResults(limit: Int = 14) -> [EvalResult] {
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

    func saveArticle(_ article: KnowledgeArticle) {
        let sql = """
            INSERT INTO facts (subject, predicate, object, confidence, source, created_at, updated_at)
            VALUES (?, 'article_content', ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let now = Date().timeIntervalSince1970
            sqlite3_bind_text(stmt, 1, article.title, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_text(stmt, 2, article.content, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_double(stmt, 3, 0.9)
            sqlite3_bind_text(stmt, 4, article.source, -1, SQLITE_TRANSIENT_FUNC)
            sqlite3_bind_double(stmt, 5, now)
            sqlite3_bind_double(stmt, 6, now)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func recentArticleTitles(limit: Int = 5) -> [String] {
        var results: [String] = []
        let sql = "SELECT subject FROM facts WHERE predicate = 'article_content' ORDER BY created_at DESC LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(String(cString: sqlite3_column_text(stmt, 0)))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func recentUserMessages(limit: Int = 10) -> [String] {
        var results: [String] = []
        let sql = "SELECT content FROM conversations WHERE role = 'user' ORDER BY timestamp DESC LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(String(cString: sqlite3_column_text(stmt, 0)))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func randomArticles(limit: Int = 3) -> [KnowledgeArticle] {
        var results: [KnowledgeArticle] = []
        let sql = "SELECT subject, object, source, created_at FROM facts WHERE predicate = 'article_content' ORDER BY RANDOM() LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let title = String(cString: sqlite3_column_text(stmt, 0))
                let content = String(cString: sqlite3_column_text(stmt, 1))
                let source = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "Eon"
                let ts = sqlite3_column_double(stmt, 3)
                results.append(KnowledgeArticle(
                    title: title,
                    content: content,
                    summary: String(content.prefix(120)),
                    domain: "AI & Teknik",
                    source: source,
                    date: Date(timeIntervalSince1970: ts),
                    isAutonomous: true
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - Search facts by keyword (for prompt enrichment)

    func searchFacts(query: String, limit: Int = 5) -> [(subject: String, predicate: String, object: String)] {
        var results: [(String, String, String)] = []
        let keywords = query.lowercased().split(separator: " ").filter { $0.count > 3 }.map(String.init)
        guard !keywords.isEmpty else { return [] }
        let likeClause = keywords.prefix(3).map { _ in "(subject LIKE ? OR object LIKE ?)" }.joined(separator: " OR ")
        let sql = "SELECT subject, predicate, object FROM facts WHERE \(likeClause) ORDER BY confidence DESC LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            var idx: Int32 = 1
            for kw in keywords.prefix(3) {
                let pattern = "%\(kw)%"
                sqlite3_bind_text(stmt, idx, (pattern as NSString).utf8String, -1, nil); idx += 1
                sqlite3_bind_text(stmt, idx, (pattern as NSString).utf8String, -1, nil); idx += 1
            }
            sqlite3_bind_int(stmt, idx, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let s = String(cString: sqlite3_column_text(stmt, 0))
                let p = String(cString: sqlite3_column_text(stmt, 1))
                let o = String(cString: sqlite3_column_text(stmt, 2))
                results.append((s, p, o))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - Recent facts (for ICA world model)

    func recentFacts(limit: Int = 10) -> [(subject: String, predicate: String, object: String)] {
        var results: [(String, String, String)] = []
        let sql = "SELECT subject, predicate, object FROM facts ORDER BY created_at DESC LIMIT ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let s = String(cString: sqlite3_column_text(stmt, 0))
                let p = String(cString: sqlite3_column_text(stmt, 1))
                let o = String(cString: sqlite3_column_text(stmt, 2))
                results.append((s, p, o))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - Helper

    @discardableResult
    private func execute(_ sql: String) -> Bool {
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
