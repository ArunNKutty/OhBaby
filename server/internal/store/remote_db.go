package store

import (
	"context"
	"database/sql"
	"fmt"
	"strconv"
	"strings"
	"time"
)

// database is the SQL surface the store uses. The file-backed store uses DuckDB
// directly. The Quack store sends each statement to the DuckDB server.
type database interface {
	Close() error
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
	BeginTx(ctx context.Context, opts *sql.TxOptions) (transaction, error)
}

type transaction interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	Commit() error
	Rollback() error
}

type localDB struct{ *sql.DB }

func (l localDB) BeginTx(ctx context.Context, opts *sql.TxOptions) (transaction, error) {
	return l.DB.BeginTx(ctx, opts)
}

// remoteDB keeps a local DuckDB client only to speak Quack. ATTACH is broken in
// DuckDB 1.5.6 (the catalog never registers), so statements go through quack_query.
type remoteDB struct {
	local *sql.DB
	uri   string
	token string
}

func (r remoteDB) Close() error { return r.local.Close() }

func (r remoteDB) ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error) {
	bound, err := bindSQL(query, args)
	if err != nil {
		return nil, err
	}
	if _, err := r.local.ExecContext(ctx, `FROM quack_query(?, ?, token := ?, disable_ssl := true)`, r.uri, bound, r.token); err != nil {
		return nil, err
	}
	return emptyResult{}, nil
}

func (r remoteDB) QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error) {
	bound, err := bindSQL(query, args)
	if err != nil {
		return nil, err
	}
	return r.local.QueryContext(ctx, `FROM quack_query(?, ?, token := ?, disable_ssl := true)`, r.uri, bound, r.token)
}

func (r remoteDB) QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row {
	bound, err := bindSQL(query, args)
	if err != nil {
		return r.local.QueryRowContext(ctx, `SELECT 1 WHERE 1 = 0`)
	}
	return r.local.QueryRowContext(ctx, `FROM quack_query(?, ?, token := ?, disable_ssl := true)`, r.uri, bound, r.token)
}

func (r remoteDB) BeginTx(context.Context, *sql.TxOptions) (transaction, error) {
	return &remoteTx{parent: r}, nil
}

type remoteTx struct {
	parent remoteDB
	stmts  []string
	done   bool
}

func (t *remoteTx) ExecContext(_ context.Context, query string, args ...any) (sql.Result, error) {
	if t.done {
		return nil, sql.ErrTxDone
	}
	bound, err := bindSQL(query, args)
	if err != nil {
		return nil, err
	}
	t.stmts = append(t.stmts, bound)
	return emptyResult{}, nil
}

func (t *remoteTx) Commit() error {
	if t.done {
		return sql.ErrTxDone
	}
	t.done = true
	script := "BEGIN TRANSACTION; " + strings.Join(t.stmts, "; ") + "; COMMIT;"
	_, err := t.parent.ExecContext(context.Background(), script)
	return err
}

func (t *remoteTx) Rollback() error {
	if t.done {
		return nil
	}
	t.done = true
	return nil
}

type emptyResult struct{}

func (emptyResult) LastInsertId() (int64, error) { return 0, nil }
func (emptyResult) RowsAffected() (int64, error) { return 0, nil }

func bindSQL(query string, args []any) (string, error) {
	var b strings.Builder
	n := 0
	inQuote := false
	for i := 0; i < len(query); i++ {
		ch := query[i]
		if inQuote {
			b.WriteByte(ch)
			if ch == '\'' {
				if i+1 < len(query) && query[i+1] == '\'' {
					b.WriteByte('\'')
					i++
					continue
				}
				inQuote = false
			}
			continue
		}
		if ch == '\'' {
			inQuote = true
			b.WriteByte(ch)
			continue
		}
		if ch == '?' {
			if n >= len(args) {
				return "", fmt.Errorf("not enough SQL arguments")
			}
			lit, err := sqlLiteral(args[n])
			if err != nil {
				return "", err
			}
			b.WriteString(lit)
			n++
			continue
		}
		b.WriteByte(ch)
	}
	if n != len(args) {
		return "", fmt.Errorf("too many SQL arguments")
	}
	return b.String(), nil
}

func sqlLiteral(v any) (string, error) {
	if v == nil {
		return "NULL", nil
	}
	switch t := v.(type) {
	case string:
		return "'" + strings.ReplaceAll(t, "'", "''") + "'", nil
	case *string:
		if t == nil {
			return "NULL", nil
		}
		return sqlLiteral(*t)
	case time.Time:
		return "TIMESTAMP '" + t.UTC().Format("2006-01-02 15:04:05.999999") + "'", nil
	case int:
		return strconv.Itoa(t), nil
	case int64:
		return strconv.FormatInt(t, 10), nil
	case float64:
		return strconv.FormatFloat(t, 'g', -1, 64), nil
	case bool:
		if t {
			return "TRUE", nil
		}
		return "FALSE", nil
	default:
		return "", fmt.Errorf("cannot send %T to DuckDB", v)
	}
}
