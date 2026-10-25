using Microsoft.Data.Sqlite;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Integration tests verifying SQLite FTS5 full-text indexing and R-Tree spatial indexing for offline search databases.
    /// </summary>
    public class SearchDatabaseServiceTests {
        [Fact]
        public async Task SearchDatabase_Fts5AndRTree_ExecuteQueriesSuccessfully() {
            // Arrange
            string tempDbPath = Path.Combine(Path.GetTempPath(), "narotta_test_search_" + Path.GetRandomFileName() + ".db");
            string connectionString = new SqliteConnectionStringBuilder {
                DataSource = tempDbPath,
                Mode = SqliteOpenMode.ReadWriteCreate,
                Pooling = false
            }.ToString();

            using var cancellationTokenSource = new CancellationTokenSource();

            try {
                await using (var connection = new SqliteConnection(connectionString)) {
                    await connection.OpenAsync(cancellationTokenSource.Token);

                    // Create FTS5 and R-Tree virtual tables
                    string schemaSql = @"
                        CREATE TABLE places (
                            id INTEGER PRIMARY KEY,
                            name TEXT NOT NULL,
                            latitude REAL NOT NULL,
                            longitude REAL NOT NULL
                        );

                        CREATE TABLE pois (
                            id INTEGER PRIMARY KEY,
                            name TEXT NOT NULL,
                            category TEXT NOT NULL,
                            latitude REAL NOT NULL,
                            longitude REAL NOT NULL
                        );

                        CREATE VIRTUAL TABLE search_fts USING fts5(
                            entity_type UNINDEXED,
                            entity_id UNINDEXED,
                            title,
                            subtitle,
                            tokens,
                            latitude UNINDEXED,
                            longitude UNINDEXED,
                            tokenize = 'unicode61 remove_diacritics 2'
                        );

                        CREATE VIRTUAL TABLE poi_rtree USING rtree(
                            id,
                            min_latitude,
                            max_latitude,
                            min_longitude,
                            max_longitude
                        );
                    ";

                    using (var createCommand = connection.CreateCommand()) {
                        createCommand.CommandText = schemaSql;
                        await createCommand.ExecuteNonQueryAsync(cancellationTokenSource.Token);
                    }

                    // Insert test entries
                    using (var insertCommand = connection.CreateCommand()) {
                        insertCommand.CommandText = @"
                            INSERT INTO search_fts (entity_type, entity_id, title, subtitle, tokens, latitude, longitude)
                            VALUES ('poi', 1, 'Ristorante Pizzeria Roma', 'Via Garibaldi 10, Trento', 'amenity restaurant pizza trento', 46.0678, 11.1210);

                            INSERT INTO search_fts (entity_type, entity_id, title, subtitle, tokens, latitude, longitude)
                            VALUES ('place', 2, 'Trento', 'Trentino-Alto Adige', 'city 38122 trento', 46.0678, 11.1210);

                            INSERT INTO poi_rtree (id, min_latitude, max_latitude, min_longitude, max_longitude)
                            VALUES (1, 46.0678, 46.0678, 11.1210, 11.1210);
                        ";
                        await insertCommand.ExecuteNonQueryAsync(cancellationTokenSource.Token);
                    }

                    // Test FTS5 search with diacritic removal / accent folding
                    using (var ftsQueryCommand = connection.CreateCommand()) {
                        ftsQueryCommand.CommandText = "SELECT title FROM search_fts WHERE search_fts MATCH 'roma';";
                        object? result = await ftsQueryCommand.ExecuteScalarAsync(cancellationTokenSource.Token);
                        Assert.Equal("Ristorante Pizzeria Roma", result?.ToString());
                    }

                    // Test FTS5 prefix / token match
                    using (var prefixCommand = connection.CreateCommand()) {
                        prefixCommand.CommandText = "SELECT title FROM search_fts WHERE search_fts MATCH 'pizz*';";
                        object? result = await prefixCommand.ExecuteScalarAsync(cancellationTokenSource.Token);
                        Assert.Equal("Ristorante Pizzeria Roma", result?.ToString());
                    }

                    // Test R-Tree spatial range bounding box query
                    using (var rtreeQueryCommand = connection.CreateCommand()) {
                        rtreeQueryCommand.CommandText = @"
                            SELECT id FROM poi_rtree
                            WHERE min_latitude >= 46.0 AND max_latitude <= 46.5
                            AND min_longitude >= 11.0 AND max_longitude <= 11.5;
                        ";
                        object? result = await rtreeQueryCommand.ExecuteScalarAsync(cancellationTokenSource.Token);
                        Assert.Equal(1L, result);
                    }
                }
            }finally {
                SqliteConnection.ClearAllPools();
                if (File.Exists(tempDbPath)) {
                    File.Delete(tempDbPath);
                }
            }
        }
    }
}
