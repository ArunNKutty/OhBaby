package store

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"embed"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/duckdb/duckdb-go/v2"
	_ "github.com/duckdb/duckdb-go/v2"
	"github.com/google/uuid"
)

func duckUUID(s string) (duckdb.UUID, error) {
	parsed, err := uuid.Parse(s)
	if err != nil {
		return duckdb.UUID{}, err
	}
	var out duckdb.UUID
	copy(out[:], parsed[:])
	return out, nil
}

//go:embed migrations/*.sql
var migrationFS embed.FS

var (
	ErrNotFound = errors.New("not found")
	ErrConflict = errors.New("conflict")
)

// Feeding is one logged feed. Type formula is what the app calls a formula bottle.
type Feeding struct {
	ID        string
	BabyID    string
	Type      string
	StartUTC  time.Time
	EndUTC    time.Time
	OffsetMin int
	LeftMs    int
	RightMs   int
	EndSide   *string
	AmountMl  int
	Notes     string
	CreatedBy string
	UpdatedAt time.Time
	DeletedAt *time.Time
	ChangeNo  int64
}

type Baby struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	BirthDate *string   `json:"birth_date"`
	Role      string    `json:"role"`
	CreatedAt time.Time `json:"created_at"`
}

type User struct {
	ID        string
	Email     string
	GoogleSub string
	CreatedAt time.Time
}

type Event struct {
	ID         string
	Name       string
	ClientTS   time.Time
	AnonID     string
	UserID     *string
	SessionID  string
	Platform   string
	AppVersion string
	PropsJSON  string
}

type Store struct {
	db        database
	connector *duckdb.Connector
	remote    bool
}

var (
	remoteURI   = regexp.MustCompile(`^quack:[A-Za-z0-9._-]+:[0-9]+$`)
	remoteToken = regexp.MustCompile(`^[A-Za-z0-9._-]{4,128}$`)
)

func Open(path string) (*Store, error) {
	if path != "" && path != ":memory:" {
		if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
			return nil, err
		}
	}
	connector, err := duckdb.NewConnector(path, nil)
	if err != nil {
		return nil, err
	}
	db := sql.OpenDB(connector)
	db.SetMaxOpenConns(4)
	s := &Store{db: localDB{db}, connector: connector}
	if err := s.migrate(context.Background()); err != nil {
		_ = db.Close()
		return nil, err
	}
	return s, nil
}

// OpenRemote attaches a DuckDB Quack server. The database file stays in that server.
// This process only keeps an in-memory DuckDB client so it can speak the Quack protocol.
func OpenRemote(uri, token string) (*Store, error) {
	if !remoteURI.MatchString(uri) {
		return nil, fmt.Errorf("OHBABY_DB must look like quack:hostname:9494")
	}
	if !remoteToken.MatchString(token) {
		return nil, fmt.Errorf("DUCKDB_QUACK_TOKEN must be 4-128 letters, numbers, dots, or dashes")
	}
	init := func(execer driver.ExecerContext) error {
		ctx := context.Background()
		steps := []string{
			"SET extension_directory='/opt/duckdb-extensions'",
			"INSTALL httpfs",
			"LOAD httpfs",
			"INSTALL quack",
			"LOAD quack",
		}
		for _, query := range steps {
			if _, err := execer.ExecContext(ctx, query, nil); err != nil {
				return fmt.Errorf("%s: %w", query, err)
			}
		}
		return nil
	}
	connector, err := duckdb.NewConnector("", init)
	if err != nil {
		return nil, err
	}
	db := sql.OpenDB(connector)
	db.SetMaxOpenConns(8)
	s := &Store{db: remoteDB{local: db, uri: uri, token: token}, connector: connector, remote: true}
	if err := s.migrate(context.Background()); err != nil {
		_ = db.Close()
		return nil, err
	}
	return s, nil
}

func (s *Store) Close() error { return s.db.Close() }

func (s *Store) Ping(ctx context.Context) error {
	var n int
	return s.db.QueryRowContext(ctx, `SELECT 1`).Scan(&n)
}

func (s *Store) migrate(ctx context.Context) error {
	if _, err := s.db.ExecContext(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL)`); err != nil {
		return err
	}
	rows, err := s.db.QueryContext(ctx, `SELECT version FROM schema_migrations`)
	if err != nil {
		return err
	}
	applied := map[int]bool{}
	for rows.Next() {
		var version int
		if err := rows.Scan(&version); err != nil {
			_ = rows.Close()
			return err
		}
		applied[version] = true
	}
	if err := rows.Close(); err != nil {
		return err
	}
	steps := []struct {
		version int
		file    string
	}{
		{1, "migrations/001_init.sql"},
		{2, "migrations/002_firebase.sql"},
	}
	for _, step := range steps {
		if applied[step.version] {
			continue
		}
		sqlBytes, err := migrationFS.ReadFile(step.file)
		if err != nil {
			return err
		}
		for _, stmt := range splitSQL(string(sqlBytes)) {
			if _, err := s.db.ExecContext(ctx, stmt); err != nil {
				return fmt.Errorf("migration %d: %w\n%s", step.version, err, stmt)
			}
		}
		if _, err := s.db.ExecContext(ctx, `INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)`, step.version, time.Now().UTC()); err != nil {
			return err
		}
	}
	return nil
}

func splitSQL(in string) []string {
	parts := strings.Split(in, ";")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

func isConflict(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "conflict") || strings.Contains(msg, "transactioncontext")
}

func (s *Store) exec(ctx context.Context, query string, args ...any) error {
	var err error
	for i := 0; i < 5; i++ {
		_, err = s.db.ExecContext(ctx, query, args...)
		if err == nil || !isConflict(err) {
			return err
		}
		time.Sleep(time.Duration(i+1) * 5 * time.Millisecond)
	}
	return err
}

func (s *Store) CreateUser(ctx context.Context, id, email, googleSub string) error {
	return s.exec(ctx, `INSERT INTO users (id, email, google_sub, created_at) VALUES (?, ?, ?, ?)`,
		id, email, googleSub, time.Now().UTC())
}

// UpsertFirebaseUser finds or creates the account for a verified Firebase user.
func (s *Store) UpsertFirebaseUser(ctx context.Context, id, email, firebaseUID string) (string, error) {
	var existing dbID
	err := s.db.QueryRowContext(ctx, `SELECT id FROM users WHERE firebase_uid = ? AND deleted_at IS NULL`, firebaseUID).Scan(&existing)
	if err == nil {
		return string(existing), nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", err
	}
	err = s.db.QueryRowContext(ctx, `SELECT id FROM users WHERE email = ? AND deleted_at IS NULL`, email).Scan(&existing)
	if err == nil {
		if err := s.exec(ctx, `UPDATE users SET firebase_uid = ? WHERE id = ?`, firebaseUID, string(existing)); err != nil {
			return "", err
		}
		return string(existing), nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", err
	}
	if err := s.exec(ctx, `INSERT INTO users (id, email, firebase_uid, created_at) VALUES (?, ?, ?, ?)`,
		id, email, firebaseUID, time.Now().UTC()); err != nil {
		return "", err
	}
	return id, nil
}

// UpsertGoogleUser finds or creates the account for a verified Google identity.
func (s *Store) UpsertGoogleUser(ctx context.Context, id, email, googleSub string) (string, error) {
	var existing dbID
	err := s.db.QueryRowContext(ctx, `SELECT id FROM users WHERE google_sub = ? AND deleted_at IS NULL`, googleSub).Scan(&existing)
	if err == nil {
		return string(existing), nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", err
	}
	err = s.db.QueryRowContext(ctx, `SELECT id FROM users WHERE email = ? AND deleted_at IS NULL`, email).Scan(&existing)
	if err == nil {
		if err := s.exec(ctx, `UPDATE users SET google_sub = ? WHERE id = ?`, googleSub, string(existing)); err != nil {
			return "", err
		}
		return string(existing), nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", err
	}
	if err := s.CreateUser(ctx, id, email, googleSub); err != nil {
		return "", err
	}
	return id, nil
}

func (s *Store) GetUser(ctx context.Context, id string) (User, error) {
	var u User
	var idCol dbID
	err := s.db.QueryRowContext(ctx, `SELECT id, email, coalesce(google_sub, ''), created_at FROM users WHERE id = ? AND deleted_at IS NULL`, id).
		Scan(&idCol, &u.Email, &u.GoogleSub, &u.CreatedAt)
	u.ID = string(idCol)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, ErrNotFound
	}
	return u, err
}

func (s *Store) SaveRefreshToken(ctx context.Context, id, userID, hash string, expires time.Time) error {
	return s.exec(ctx, `INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at, created_at) VALUES (?, ?, ?, ?, ?)`,
		id, userID, hash, expires.UTC(), time.Now().UTC())
}

// RotateRefresh revokes the presented token and stores its replacement.
func (s *Store) RotateRefresh(ctx context.Context, oldHash, newID, newHash string, newExpires time.Time) (string, error) {
	var userID dbID
	var expires time.Time
	var revoked sql.NullTime
	err := s.db.QueryRowContext(ctx, `SELECT user_id, expires_at, revoked_at FROM refresh_tokens WHERE token_hash = ?`, oldHash).
		Scan(&userID, &expires, &revoked)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", err
	}
	if revoked.Valid || time.Now().After(expires) {
		return "", ErrNotFound
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return "", err
	}
	defer func() { _ = tx.Rollback() }()
	if _, err := tx.ExecContext(ctx, `UPDATE refresh_tokens SET revoked_at = ? WHERE token_hash = ? AND revoked_at IS NULL`, time.Now().UTC(), oldHash); err != nil {
		return "", err
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at, created_at) VALUES (?, ?, ?, ?, ?)`,
		newID, string(userID), newHash, newExpires.UTC(), time.Now().UTC()); err != nil {
		return "", err
	}
	if err := tx.Commit(); err != nil {
		return "", err
	}
	return string(userID), nil
}

func (s *Store) RevokeUserTokens(ctx context.Context, userID string) error {
	return s.exec(ctx, `UPDATE refresh_tokens SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL`, time.Now().UTC(), userID)
}

func (s *Store) CreateBaby(ctx context.Context, userID, babyID, name string, birth *string) (Baby, error) {
	role, err := s.role(ctx, userID, babyID)
	if err != nil && !errors.Is(err, ErrNotFound) {
		return Baby{}, err
	}
	if role != "" {
		if name != "" {
			if err := s.exec(ctx, `UPDATE babies SET name = ? WHERE id = ?`, name, babyID); err != nil {
				return Baby{}, err
			}
		}
		return s.GetBaby(ctx, userID, babyID)
	}
	var owner dbID
	err = s.db.QueryRowContext(ctx, `SELECT user_id FROM memberships WHERE baby_id = ? AND role = 'owner'`, babyID).Scan(&owner)
	if err == nil && string(owner) != userID {
		return Baby{}, ErrConflict
	}
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return Baby{}, err
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Baby{}, err
	}
	defer func() { _ = tx.Rollback() }()
	now := time.Now().UTC()
	if _, err := tx.ExecContext(ctx, `INSERT INTO babies (id, name, birth_date, created_at) VALUES (?, ?, ?, ?)`, babyID, name, birth, now); err != nil {
		return Baby{}, err
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO memberships (user_id, baby_id, role) VALUES (?, ?, 'owner')`, userID, babyID); err != nil {
		return Baby{}, err
	}
	if err := tx.Commit(); err != nil {
		return Baby{}, err
	}
	return s.GetBaby(ctx, userID, babyID)
}

func (s *Store) role(ctx context.Context, userID, babyID string) (string, error) {
	var role string
	err := s.db.QueryRowContext(ctx, `SELECT role FROM memberships WHERE user_id = ? AND baby_id = ?`, userID, babyID).Scan(&role)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	return role, err
}

func (s *Store) GetBaby(ctx context.Context, userID, babyID string) (Baby, error) {
	var b Baby
	var birth sql.NullTime
	var idCol dbID
	err := s.db.QueryRowContext(ctx, `
		SELECT b.id, b.name, b.birth_date, b.created_at, m.role
		FROM babies b
		JOIN memberships m ON m.baby_id = b.id
		WHERE b.id = ? AND m.user_id = ?`, babyID, userID).Scan(&idCol, &b.Name, &birth, &b.CreatedAt, &b.Role)
	b.ID = string(idCol)
	if errors.Is(err, sql.ErrNoRows) {
		return Baby{}, ErrNotFound
	}
	if err != nil {
		return Baby{}, err
	}
	if birth.Valid {
		d := birth.Time.Format("2006-01-02")
		b.BirthDate = &d
	}
	return b, nil
}

func (s *Store) ListBabies(ctx context.Context, userID string) ([]Baby, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT b.id, b.name, b.birth_date, b.created_at, m.role
		FROM babies b
		JOIN memberships m ON m.baby_id = b.id
		WHERE m.user_id = ?
		ORDER BY b.created_at`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Baby
	for rows.Next() {
		var b Baby
		var birth sql.NullTime
		var idCol dbID
		if err := rows.Scan(&idCol, &b.Name, &birth, &b.CreatedAt, &b.Role); err != nil {
			return nil, err
		}
		b.ID = string(idCol)
		if birth.Valid {
			d := birth.Time.Format("2006-01-02")
			b.BirthDate = &d
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

func (s *Store) RenameBaby(ctx context.Context, userID, babyID, name string) (Baby, error) {
	if _, err := s.role(ctx, userID, babyID); err != nil {
		return Baby{}, err
	}
	if err := s.exec(ctx, `UPDATE babies SET name = ? WHERE id = ?`, name, babyID); err != nil {
		return Baby{}, err
	}
	return s.GetBaby(ctx, userID, babyID)
}

func (s *Store) UpsertFeeding(ctx context.Context, userID string, f Feeding) (Feeding, error) {
	if _, err := s.role(ctx, userID, f.BabyID); err != nil {
		return Feeding{}, err
	}
	existing, err := s.getFeeding(ctx, f.ID)
	if err != nil && !errors.Is(err, ErrNotFound) {
		return Feeding{}, err
	}
	if err == nil && existing.BabyID != f.BabyID {
		return Feeding{}, ErrConflict
	}
	f.CreatedBy = userID
	if existing.CreatedBy != "" {
		f.CreatedBy = existing.CreatedBy
	}
	err = s.exec(ctx, `
		INSERT INTO feedings (
			id, baby_id, type, start_utc, end_utc, utc_offset_min,
			left_ms, right_ms, end_side, amount_ml, notes, created_by, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT (id) DO UPDATE SET
			type = excluded.type,
			start_utc = excluded.start_utc,
			end_utc = excluded.end_utc,
			utc_offset_min = excluded.utc_offset_min,
			left_ms = excluded.left_ms,
			right_ms = excluded.right_ms,
			end_side = excluded.end_side,
			amount_ml = excluded.amount_ml,
			notes = excluded.notes,
			updated_at = excluded.updated_at,
			deleted_at = NULL,
			change_no = nextval('change_seq')
		WHERE feedings.baby_id = excluded.baby_id
		  AND feedings.updated_at <= excluded.updated_at`,
		f.ID, f.BabyID, f.Type, f.StartUTC.UTC(), f.EndUTC.UTC(), f.OffsetMin,
		f.LeftMs, f.RightMs, f.EndSide, f.AmountMl, f.Notes, f.CreatedBy, f.UpdatedAt.UTC(),
	)
	if err != nil {
		return Feeding{}, err
	}
	return s.getFeeding(ctx, f.ID)
}

func (s *Store) DeleteFeeding(ctx context.Context, userID, babyID, feedingID string, at time.Time) (Feeding, error) {
	if _, err := s.role(ctx, userID, babyID); err != nil {
		return Feeding{}, err
	}
	existing, err := s.getFeeding(ctx, feedingID)
	if err != nil {
		return Feeding{}, err
	}
	if existing.BabyID != babyID {
		return Feeding{}, ErrNotFound
	}
	if existing.DeletedAt == nil {
		if err := s.exec(ctx, `
			UPDATE feedings
			SET deleted_at = ?, updated_at = ?, change_no = nextval('change_seq')
			WHERE id = ? AND baby_id = ?`, at.UTC(), at.UTC(), feedingID, babyID); err != nil {
			return Feeding{}, err
		}
	}
	return s.getFeeding(ctx, feedingID)
}

func (s *Store) FeedingsSince(ctx context.Context, userID, babyID string, since int64) ([]Feeding, int64, error) {
	if _, err := s.role(ctx, userID, babyID); err != nil {
		return nil, 0, err
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, baby_id, type, start_utc, end_utc, utc_offset_min, left_ms, right_ms,
		       end_side, amount_ml, notes, created_by, updated_at, deleted_at, change_no
		FROM feedings
		WHERE baby_id = ? AND change_no > ?
		ORDER BY change_no`, babyID, since)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	list, err := scanFeedings(rows)
	if err != nil {
		return nil, 0, err
	}
	next := since
	for _, f := range list {
		if f.ChangeNo > next {
			next = f.ChangeNo
		}
	}
	return list, next, nil
}

func (s *Store) FeedingsForBaby(ctx context.Context, userID, babyID string) ([]Feeding, error) {
	if _, err := s.role(ctx, userID, babyID); err != nil {
		return nil, err
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, baby_id, type, start_utc, end_utc, utc_offset_min, left_ms, right_ms,
		       end_side, amount_ml, notes, created_by, updated_at, deleted_at, change_no
		FROM feedings
		WHERE baby_id = ? AND deleted_at IS NULL
		ORDER BY start_utc`, babyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanFeedings(rows)
}

func (s *Store) getFeeding(ctx context.Context, id string) (Feeding, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, baby_id, type, start_utc, end_utc, utc_offset_min, left_ms, right_ms,
		       end_side, amount_ml, notes, created_by, updated_at, deleted_at, change_no
		FROM feedings WHERE id = ?`, id)
	if err != nil {
		return Feeding{}, err
	}
	defer rows.Close()
	list, err := scanFeedings(rows)
	if err != nil {
		return Feeding{}, err
	}
	if len(list) == 0 {
		return Feeding{}, ErrNotFound
	}
	return list[0], nil
}

func scanFeedings(rows *sql.Rows) ([]Feeding, error) {
	var out []Feeding
	for rows.Next() {
		var f Feeding
		var endSide sql.NullString
		var deleted sql.NullTime
		var left, right, amount, offset int64
		var idCol, babyCol, createdCol dbID
		if err := rows.Scan(
			&idCol, &babyCol, &f.Type, &f.StartUTC, &f.EndUTC, &offset, &left, &right,
			&endSide, &amount, &f.Notes, &createdCol, &f.UpdatedAt, &deleted, &f.ChangeNo,
		); err != nil {
			return nil, err
		}
		f.ID = string(idCol)
		f.BabyID = string(babyCol)
		f.CreatedBy = string(createdCol)
		f.OffsetMin = int(offset)
		f.LeftMs = int(left)
		f.RightMs = int(right)
		f.AmountMl = int(amount)
		if endSide.Valid {
			v := endSide.String
			f.EndSide = &v
		}
		if deleted.Valid {
			t := deleted.Time
			f.DeletedAt = &t
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// AppendEvents writes a batch with the DuckDB appender.
func (s *Store) AppendEvents(ctx context.Context, events []Event) error {
	if len(events) == 0 {
		return nil
	}
	if s.remote {
		return s.insertEvents(ctx, events)
	}
	conn, err := s.connector.Connect(ctx)
	if err != nil {
		return err
	}
	defer conn.Close()
	app, err := duckdb.NewAppenderFromConn(conn, "", "events")
	if err != nil {
		return err
	}
	received := time.Now().UTC()
	for _, e := range events {
		var user any
		if e.UserID != nil && *e.UserID != "" {
			parsed, err := duckUUID(*e.UserID)
			if err != nil {
				_ = app.Close()
				return err
			}
			user = parsed
		}
		props := e.PropsJSON
		if props == "" {
			props = "{}"
		}
		eventID, err := duckUUID(e.ID)
		if err != nil {
			_ = app.Close()
			return err
		}
		anonID, err := duckUUID(e.AnonID)
		if err != nil {
			_ = app.Close()
			return err
		}
		sessionID, err := duckUUID(e.SessionID)
		if err != nil {
			_ = app.Close()
			return err
		}
		if err := app.AppendRow(
			eventID,
			e.Name,
			e.ClientTS.UTC(),
			received,
			anonID,
			user,
			sessionID,
			e.Platform,
			e.AppVersion,
			props,
		); err != nil {
			_ = app.Close()
			return err
		}
	}
	return app.Close()
}

func (s *Store) insertEvents(ctx context.Context, events []Event) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	received := time.Now().UTC()
	for _, e := range events {
		props := e.PropsJSON
		if props == "" {
			props = "{}"
		}
		var user any
		if e.UserID != nil && *e.UserID != "" {
			user = *e.UserID
		}
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO events (
				event_id, name, client_ts, received_at, anon_id, user_id, session_id, platform, app_version, props
			) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CAST(? AS JSON))`,
			e.ID, e.Name, e.ClientTS.UTC(), received, e.AnonID, user, e.SessionID, e.Platform, e.AppVersion, props,
		); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (s *Store) CountEvents(ctx context.Context) (int, error) {
	var n int
	err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM events`).Scan(&n)
	return n, err
}

// DeleteUser removes the account and the babies they own.
func (s *Store) DeleteUser(ctx context.Context, userID string) error {
	babies, err := s.ListBabies(ctx, userID)
	if err != nil {
		return err
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	for _, b := range babies {
		if b.Role != "owner" {
			if _, err := tx.ExecContext(ctx, `DELETE FROM memberships WHERE user_id = ? AND baby_id = ?`, userID, b.ID); err != nil {
				return err
			}
			continue
		}
		if _, err := tx.ExecContext(ctx, `DELETE FROM feedings WHERE baby_id = ?`, b.ID); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `DELETE FROM memberships WHERE baby_id = ?`, b.ID); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `DELETE FROM babies WHERE id = ?`, b.ID); err != nil {
			return err
		}
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM refresh_tokens WHERE user_id = ?`, userID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `UPDATE events SET user_id = NULL WHERE user_id = ?`, userID); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM users WHERE id = ?`, userID); err != nil {
		return err
	}
	return tx.Commit()
}

// ExportParquet writes a DuckDB EXPORT DATABASE snapshot. Object storage is a hosting concern.
func (s *Store) ExportParquet(ctx context.Context, dir string) error {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	// EXPORT DATABASE does not take a bound parameter.
	escaped := strings.ReplaceAll(dir, "'", "''")
	_, err := s.db.ExecContext(ctx, fmt.Sprintf(`EXPORT DATABASE '%s' (FORMAT PARQUET)`, escaped))
	return err
}
