# Minimal fake of the AiStack audio service for tools/e2e/voice_e2e.sh
# (shapes per forge/internal/worker/audio.go). Args: port tone.wav log.
import json, sys, subprocess, itertools
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
WAV = sys.argv[2]
ids = itertools.count(1)
jobs = {}
log = open(sys.argv[3], 'a')
class H(BaseHTTPRequestHandler):
    def _send(self, code, body=b'', ctype='application/json'):
        self.send_response(code); self.send_header('content-type', ctype)
        self.send_header('content-length', str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_POST(self):
        n = int(self.headers.get('content-length', 0)); body = self.rfile.read(n)
        if self.path == '/v1/audio/voices':
            log.write(f"VOICE_UPLOAD bytes={n}\n"); log.flush()
            return self._send(201, b'{"voice_id":"x"}')
        if self.path == '/v1/audio/tts':
            req = json.loads(body); j = str(next(ids)); jobs[j] = req
            log.write(f"TTS voice={req.get('voice')} speed={req.get('speed')} co={req.get('commercial_only')} text={req.get('text')[:40]}\n"); log.flush()
            return self._send(202, json.dumps({"job_id": j, "status": "queued", "queue_position": 0}).encode())
        self._send(404)
    def do_GET(self):
        p = self.path.split('/')
        if self.path.startswith('/v1/audio/jobs/') and len(p) == 5:
            return self._send(200, json.dumps({"job_id": p[4], "status": "done", "outputs": [{"url": f"/v1/audio/jobs/{p[4]}/outputs/a.wav", "filename": "a.wav", "duration": 1.0}]}).encode())
        if '/outputs/' in self.path:
            return self._send(200, open(WAV, 'rb').read(), 'audio/wav')
        self._send(404)
    def do_DELETE(self):
        log.write(f"VOICE_DELETE {self.path}\n"); log.flush(); self._send(200, b'{}')
    def log_message(self, *a): pass
ThreadingHTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
