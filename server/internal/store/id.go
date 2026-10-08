package store

import "github.com/duckdb/duckdb-go/v2"

// dbID scans a DuckDB UUID into a canonical string.
type dbID string

func (d *dbID) Scan(v any) error {
	var u duckdb.UUID
	if err := u.Scan(v); err != nil {
		return err
	}
	*d = dbID(u.String())
	return nil
}
