#if os(Linux)
    import CSQLiteLinux
#else
    import CSQLiteMac
#endif

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public class SQLite {
    /**
        The prepare closure is used
        to bind values to the SQLite statement
        in a safe, escaped manner.
    */
    public typealias PrepareClosure = ((Statement) throws -> ())

    /**
        Provides more useful type
        information for the Database pointer.
    */
    public typealias Database = OpaquePointer

    /**
        An optional pointer to the
        connection to the SQLite database.
    */
    public var database: Database?

    /**
        Opens a connection to the SQLite
        database at a given path.
     
        If the database does not already exist,
        it will be created.
    */
    public init(path: String) throws {
        let options = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &database, options, nil) != SQLITE_OK {
            throw SQLiteError.connection(database?.errorMessage ?? "")
        }
    }

    /**
        Closes a connetion to the database.
    */
    public func close() {
        sqlite3_close(database)
    }

    /**
        Closes the database when deinitialized.
    */
    deinit {
        self.close()
    }

    /**
        Executes a statement query string
        and calls the prepare closure to bind
        any prepared values.
     
        The resulting rows are returned if
        no errors occur.
    */
    public func execute(_ queryString: String, prepareClosure: PrepareClosure = { _ in }) throws -> [Result.Row] {
        guard let database = self.database else {
            throw SQLiteError.execute("No database")
        }

        let statementContainer = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
        defer {
            statementContainer.deallocate(capacity: 1)
        }

        if sqlite3_prepare_v2(database, queryString, -1, statementContainer, nil) != SQLITE_OK {
            throw SQLiteError.prepare(database.errorMessage)
        }

        guard let statementPointer = statementContainer.pointee else {
            throw SQLiteError.execute("Statement pointer errror")
        }

        let statement = Statement(pointer: statementPointer, database: database)
        try prepareClosure(statement)

        var result = Result()
        while sqlite3_step(statement.pointer) == SQLITE_ROW {
            
            var row = Result.Row()
            let count = sqlite3_column_count(statement.pointer)

            for i in 0..<count {
                try row.bind(at: i, pointer: statement.pointer)
            }

            result.rows.append(row)
        }
        
        if sqlite3_finalize(statement.pointer) != SQLITE_OK {
            throw SQLiteError.execute(database.errorMessage)
        }
        
        return result.rows
    }

    /**
        Returns an identifier for the last
        inserted row.
    */
    public var lastId: Int? {
        guard let database = database else {
            return nil
        }

        let id = sqlite3_last_insert_rowid(database)
        return Int(id)
    }

    //MARK: Error
    public enum SQLiteError: Error {
        case connection(String)
        case close(String)
        case prepare(String)
        case bind(String)
        case execute(String)
    }
}

extension SQLite.Database {
    /**
        Returns the last error message
        for the current database connection.
    */
    var errorMessage: String {
        if let raw = sqlite3_errmsg(self) {
            return String(cString: raw)
        } else {
            return "Unknown"
        }
    }

}

