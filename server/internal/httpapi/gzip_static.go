package httpapi

import (
	"compress/gzip"
	"io"
	"net/http"
	"strings"
)

type gzipResponseWriter struct {
	http.ResponseWriter
	gz *gzip.Writer
}

func (w *gzipResponseWriter) Write(b []byte) (int, error) {
	return w.gz.Write(b)
}

func withGzip(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.Contains(r.Header.Get("Accept-Encoding"), "gzip") || !gzipPath(r.URL.Path) {
			next.ServeHTTP(w, r)
			return
		}
		w.Header().Set("Content-Encoding", "gzip")
		w.Header().Set("Vary", "Accept-Encoding")
		gz := gzip.NewWriter(w)
		defer gz.Close()
		next.ServeHTTP(&gzipResponseWriter{ResponseWriter: w, gz: gz}, r)
	})
}

func gzipPath(p string) bool {
	lower := strings.ToLower(p)
	return strings.HasSuffix(lower, ".js") ||
		strings.HasSuffix(lower, ".wasm") ||
		strings.HasSuffix(lower, ".json") ||
		strings.HasSuffix(lower, ".svg")
}

// Ensure gzipResponseWriter does not implement http.Flusher when wrapped incorrectly.
var _ io.Writer = (*gzipResponseWriter)(nil)
