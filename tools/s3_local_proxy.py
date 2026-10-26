import http.server
import urllib.parse
import urllib.request
import sys
import ssl

PORT = 8089

class S3CorsProxyHandler(http.server.BaseHTTPRequestHandler):
    def _set_cors_headers(self, etag=None):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, PUT, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Access-Control-Expose-Headers', 'ETag, Content-Length, *')
        if etag:
            self.send_header('ETag', etag)

    def do_OPTIONS(self):
        self.send_response(200)
        self._set_cors_headers()
        self.send_header('Content-Length', '0')
        self.end_headers()

    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self._set_cors_headers()
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')
            return
        self.send_response(404)
        self.end_headers()

    def do_PUT(self):
        parsed = urllib.parse.urlparse(self.path)
        qs = urllib.parse.parse_qs(parsed.query)
        target_url = qs.get('url', [None])[0]

        if not target_url:
            self.send_response(400)
            self._set_cors_headers()
            self.end_headers()
            self.wfile.write(b'Missing target url')
            return

        content_length = int(self.headers.get('Content-Length', 0))

        try:
            target_parsed = urllib.parse.urlparse(target_url)
            host = target_parsed.netloc
            path_and_query = target_parsed.path + ('?' + target_parsed.query if target_parsed.query else '')

            is_https = target_parsed.scheme == 'https'
            ctx = ssl.create_default_context() if is_https else None
            # 30-minute timeout for large video parts (e.g. 450 MB chunks of 1.8 GB movie)
            if is_https:
                conn = http.client.HTTPSConnection(host, timeout=1800, context=ctx)
            else:
                conn = http.client.HTTPConnection(host, timeout=1800)

            conn.putrequest('PUT', path_and_query)
            conn.putheader('Content-Length', str(content_length))
            # Forward Content-Type only if sent by client
            ct = self.headers.get('Content-Type')
            if ct:
                conn.putheader('Content-Type', ct)
            conn.endheaders()

            # Stream body in 1 MB chunks without buffering hundreds of megabytes in memory
            remaining = content_length
            chunk_size = 1024 * 1024  # 1 MB
            while remaining > 0:
                to_read = min(chunk_size, remaining)
                chunk = self.rfile.read(to_read)
                if not chunk:
                    break
                conn.send(chunk)
                remaining -= len(chunk)

            s3_resp = conn.getresponse()
            s3_status = s3_resp.status
            s3_body = s3_resp.read()

            etag = s3_resp.getheader('ETag', '')
            if not etag:
                etag = s3_resp.getheader('etag', '')

            self.send_response(s3_status)
            self._set_cors_headers(etag=etag)
            self.send_header('Content-Length', str(len(s3_body)))
            self.end_headers()
            if s3_body:
                self.wfile.write(s3_body)
            print(f"[Proxy] Part PUT forwarded -> S3 {s3_status}, ETag: {etag}", flush=True)
            conn.close()
        except (BrokenPipeError, ConnectionResetError) as e:
            print(f"[Proxy] Client disconnected during streaming: {e}", flush=True)
        except Exception as e:
            try:
                self.send_response(500)
                self._set_cors_headers()
                self.end_headers()
                self.wfile.write(str(e).encode())
            except Exception:
                pass
            print(f"[Proxy] Exception forwarding to S3: {e}", flush=True)

    def log_message(self, format, *args):
        # Suppress noisy standard logs
        pass

if __name__ == '__main__':
    server = http.server.ThreadingHTTPServer(('127.0.0.1', PORT), S3CorsProxyHandler)
    print(f"S3 Local CORS Proxy running on http://127.0.0.1:{PORT}", flush=True)
    server.serve_forever()
