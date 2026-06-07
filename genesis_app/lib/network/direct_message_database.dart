import 'package:sqflite/sqflite.dart';

class DirectMessageDatabaseProvider {
  DirectMessageDatabaseProvider._();

  static final DirectMessageDatabaseProvider instance =
      DirectMessageDatabaseProvider._();

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final databasePath = await getDatabasesPath();
    final db = await openDatabase(
      '$databasePath/genesis_direct_messages.db',
      version: 4,
      onCreate: (db, _) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        await _migrateSchema(db, oldVersion);
      },
    );
    _database = db;
    return db;
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute(_createDmConversationsSql);
    await db.execute(_createDmSyncMetaSql);
    await db.execute(_createDmMessagesSql);
    await db.execute(_createDmMessagesIndexSql);
    await db.execute(_createDmMessageDraftsSql);
  }

  static Future<void> _migrateSchema(
    DatabaseExecutor db,
    int oldVersion,
  ) async {
    await db.execute(_createDmConversationsSql);
    await db.execute(_createDmSyncMetaSql);
    if (oldVersion < 2) {
      await db.execute(_createDmMessagesSql);
    }
    await db.execute(_createDmMessagesIndexSql);
    if (oldVersion < 3) {
      await db.execute(_createDmMessageDraftsSql);
    }
  }
}

const directMessageCursorKey = 'next_after_message_id';

const _createDmConversationsSql = '''
  CREATE TABLE IF NOT EXISTS dm_conversations (
    owner_uid TEXT NOT NULL,
    conv_id TEXT NOT NULL,
    raw_json TEXT NOT NULL,
    sort_value INTEGER NOT NULL,
    PRIMARY KEY(owner_uid, conv_id)
  )
''';

const _createDmSyncMetaSql = '''
  CREATE TABLE IF NOT EXISTS dm_sync_meta (
    owner_uid TEXT NOT NULL,
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    PRIMARY KEY(owner_uid, key)
  )
''';

const _createDmMessagesSql = '''
  CREATE TABLE IF NOT EXISTS dm_messages (
    owner_uid TEXT NOT NULL,
    peer_uid TEXT NOT NULL,
    msg_id TEXT NOT NULL,
    local_id TEXT NOT NULL,
    raw_json TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    send_status TEXT NOT NULL,
    PRIMARY KEY(owner_uid, peer_uid, msg_id)
  )
''';

const _createDmMessagesIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_dm_messages_conversation_created
  ON dm_messages(owner_uid, peer_uid, created_at, msg_id)
''';

const _createDmMessageDraftsSql = '''
  CREATE TABLE IF NOT EXISTS dm_message_drafts (
    owner_uid TEXT NOT NULL,
    peer_uid TEXT NOT NULL,
    content TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY(owner_uid, peer_uid)
  )
''';
