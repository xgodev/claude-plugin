Factory database/storage integrations. Read the linked leaf for detail.

Pick by the **Data model / role** column when the task names a category
("a document database", "an embedded key-value store", "a cache") rather than a
product. The component names alone do not encode the data model.

| Component | Data model / role | Reference |
|---|---|---|
| Mongo | Document store, over the network | `references/factory/mongo.md` |
| Firestore | Document store, GCP-managed | `references/factory/firestore.md` |
| Elasticsearch | Document store optimized for full-text search / analytics | `references/factory/elasticsearch.md` |
| Postgres (pgx) | Relational, SQL | `references/factory/pgx.md` |
| Oracle (godror) | Relational, SQL | `references/factory/godror.md` |
| Cassandra | Wide-column, distributed | `references/factory/cassandra.md` |
| BigQuery | Columnar analytics warehouse, GCP-managed -- not for OLTP | `references/factory/bigquery.md` |
| Redis | Key-value over the network; also the usual distributed cache | `references/factory/redis.md` |
| BuntDB | Embedded key-value, in-process, persists to a file | `references/factory/buntdb.md` |
| MemDB | Embedded, in-process, memory-only; requires a schema with tables + indexes | `references/factory/memdb.md` |
| BigCache | In-process cache backend (bytes), no persistence | `references/factory/bigcache.md` |
| FreeCache | In-process cache backend (bytes), no persistence | `references/factory/freecache.md` |

BigCache and FreeCache occupy the same slot -- both are in-process byte caches
usable behind the typed cache abstraction in `references/wrapper/cache.md`. Read
that file first: it is the layer most services should use, and it is what makes
the choice between the two swappable rather than structural.
