package pipeline

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

type QAReport struct {
	Stamp    string         `json:"stamp"`
	OK       bool           `json:"ok"`
	Errors   []string       `json:"errors"`
	Warnings []string       `json:"warnings"`
	Signal   map[string]any `json:"signal"`
	ASR      map[string]any `json:"asr"`
}

// QA runs python/qa_worker.py on master.opus and writes qa.json.
func (e *Env) QA(tale, voice string, length int) (*QAReport, error) {
	dir := e.TrackDir(tale, voice, length)
	var vm VoiceManifest
	if err := readJSON(filepath.Join(dir, "voice.json"), &vm); err != nil {
		return nil, fmt.Errorf("qa: run `forge voice` first: %w", err)
	}
	var mr MasterReport
	if err := readJSON(filepath.Join(dir, "master.json"), &mr); err != nil {
		return nil, fmt.Errorf("qa: run `forge master` first: %w", err)
	}
	q := e.Cfg.QA
	th := map[string]any{"wer_max": q.WERMax, "silence_max_s": q.SilenceMaxS, "silence_db": q.SilenceDB,
		"clip_dbfs": q.ClipDBFS, "hf_cutoff_hz": q.HFCutoffHz, "hf_max_rel_db": q.HFMaxRelDB, "long_pause_slack_s": q.LongPauseSlackS}
	stamp := hashParts("qa/v1", mr.Stamp, th, q.WhisperModel, os.Getenv("FORGE_QA_SKIP_ASR"))
	repPath := filepath.Join(dir, "qa.json")
	var prev QAReport
	if !e.Force && readJSON(repPath, &prev) == nil && prev.Stamp == stamp {
		e.Log.Printf("qa: %s up to date (ok=%v)", repPath, prev.OK)
		return &prev, qaErr(&prev)
	}
	req := map[string]any{"audio": filepath.Join(dir, "master.opus"), "reference_text": vm.Text,
		"intended_silences": vm.Silences, "thresholds": th, "whisper_model": q.WhisperModel, "language": q.Language}
	body, _ := json.Marshal(req)
	py := e.Cfg.Python.Cmd
	args := append(append([]string{}, py[1:]...), e.forgePath(e.Cfg.Python.QAWorker))
	cmd := exec.Command(py[0], args...)
	cmd.Stdin = bytes.NewReader(body)
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	rep := &QAReport{}
	if jerr := json.Unmarshal(out, rep); jerr != nil {
		return nil, fmt.Errorf("qa worker failed (%v): %s", err, out)
	}
	rep.Stamp = stamp
	if err := writeJSON(repPath, rep); err != nil {
		return nil, err
	}
	e.Log.Printf("qa: ok=%v errors=%v warnings=%v", rep.OK, rep.Errors, rep.Warnings)
	return rep, qaErr(rep)
}

func qaErr(r *QAReport) error {
	if r.OK {
		return nil
	}
	return fmt.Errorf("qa failed: %v", r.Errors)
}
