// Package config loads forge/config.yaml.
package config

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type Tone struct {
	Speed float64 `yaml:"speed"`
}

type Config struct {
	WorkDir string `yaml:"work_dir"`
	LLM     struct {
		Temperature    float64 `yaml:"temperature"`
		MaxTokens      int     `yaml:"max_tokens"`
		TimeoutS       int     `yaml:"timeout_s"`
		Attempts       int     `yaml:"attempts"`
		GoldDir        string  `yaml:"gold_dir"`
		Template       string  `yaml:"template"`
		JudgeChecklist string  `yaml:"judge_checklist"`
	} `yaml:"llm"`
	Speech struct {
		GapS  float64         `yaml:"gap_s"`
		Tones map[string]Tone `yaml:"tones"`
		Ramp  struct {
			Section string  `yaml:"section"`
			SpeedTo float64 `yaml:"speed_to"`
		} `yaml:"ramp"`
	} `yaml:"speech"`
	Judge struct {
		WPM                float64               `yaml:"wpm"`
		RefSpeed           float64               `yaml:"ref_speed"`
		LengthTolerance    float64               `yaml:"length_tolerance"`
		MaxSentenceWords   int                   `yaml:"max_sentence_words"`
		ForbiddenWordsFile string                `yaml:"forbidden_words_file"`
		LLM                string                `yaml:"llm"`
		LLMMinScore        float64               `yaml:"llm_min_score"`
		SectionBudgets10   map[string][2]float64 `yaml:"section_budgets_10min"`
	} `yaml:"judge"`
	Ambient struct {
		CrossfadeS float64 `yaml:"crossfade_s"`
		LUFS       float64 `yaml:"lufs"`
		TruePeak   float64 `yaml:"true_peak"`
		LRA        float64 `yaml:"lra"`
		Bitrate    string  `yaml:"bitrate"`
	} `yaml:"ambient"`
	Publish struct {
		BaseURL     string `yaml:"base_url"`
		DefaultFree bool   `yaml:"default_free"`
	} `yaml:"publish"`
	Nightly struct {
		QueueFile string `yaml:"queue_file"`
		Until     string `yaml:"until"`
		Timezone  string `yaml:"timezone"`
	} `yaml:"nightly"`
	Worker Worker `yaml:"worker"`
}

// Worker configures `forge worker` (CONTRACTS §8).
type Worker struct {
	AudioURL       string   `yaml:"audio_url"`
	VoicePrefix    string   `yaml:"voice_prefix"`
	Language       string   `yaml:"language"`
	Kinds          []string `yaml:"kinds"`
	IdleS          float64  `yaml:"idle_s"`
	HeartbeatS     float64  `yaml:"heartbeat_s"`
	PollS          float64  `yaml:"poll_s"`
	TTSTimeoutS    float64  `yaml:"tts_timeout_s"`
	ClipLUFS       float64  `yaml:"clip_lufs"`
	ClipTruePeak   float64  `yaml:"clip_true_peak"`
	ClipLRA        float64  `yaml:"clip_lra"`
	ClipBitrate    string   `yaml:"clip_bitrate"`
	ClipSampleRate int      `yaml:"clip_sample_rate"`
	// Each sentence of an utterance is a separate TTS take (chatterbox-cs often
	// stops after a short first sentence); takes are joined with this gap.
	SentenceGapS float64 `yaml:"sentence_gap_s"`
	// A take is redone (new seed) when it is too short/long for its letter
	// count or near silent; after TakeAttempts the clip is skipped (app falls
	// back to the phone voice). Letters, not words: Czech has many one-letter words.
	TakeAttempts  int     `yaml:"take_attempts"`
	MinSPerLetter float64 `yaml:"min_s_per_letter"`
	MaxSPerLetter float64 `yaml:"max_s_per_letter"`
	MinTakeLUFS   float64 `yaml:"min_take_lufs"`
}

// Default returns the built-in configuration (mirrors config.yaml).
func Default() *Config {
	c := &Config{}
	c.WorkDir = "work"
	c.LLM.Temperature = 0.7
	c.LLM.MaxTokens = 8000
	c.LLM.TimeoutS = 600
	c.LLM.Attempts = 2
	c.LLM.GoldDir = "scripts/gold"
	c.LLM.Template = "prompts/script_template.md"
	c.LLM.JudgeChecklist = "prompts/judge_checklist.md"
	c.Speech.GapS = 0.6
	c.Speech.Tones = map[string]Tone{"soft": {Speed: 0.85}, "slow": {Speed: 0.78}, "whisper": {Speed: 0.75}}
	c.Speech.Ramp.Section = "dojezd"
	c.Speech.Ramp.SpeedTo = 0.75
	c.Judge.WPM = 95
	c.Judge.RefSpeed = 0.85
	c.Judge.LengthTolerance = 0.15
	c.Judge.MaxSentenceWords = 18
	c.Judge.ForbiddenWordsFile = "prompts/forbidden_words.txt"
	c.Judge.LLM = "auto"
	c.Judge.LLMMinScore = 4
	c.Judge.SectionBudgets10 = map[string][2]float64{
		"uvod": {50, 100}, "vstup": {40, 80}, "pribeh": {270, 450}, "dojezd": {70, 130},
	}
	c.Ambient.CrossfadeS = 4
	c.Ambient.LUFS = -30
	c.Ambient.TruePeak = -3
	c.Ambient.LRA = 11
	c.Ambient.Bitrate = "96k"
	c.Publish.BaseURL = "https://lioilsources.github.io/hajanek-content/"
	c.Nightly.QueueFile = "queue.txt"
	c.Nightly.Until = "07:00"
	c.Nightly.Timezone = "Europe/Prague"
	c.Worker = Worker{
		AudioURL: "http://localhost:8093", VoicePrefix: "hajanek-", Language: "cs",
		Kinds: []string{"voice_create", "voice_delete", "render"},
		IdleS: 60, HeartbeatS: 60, PollS: 1, TTSTimeoutS: 900,
		ClipLUFS: -23, ClipTruePeak: -3, ClipLRA: 20, ClipBitrate: "64k", ClipSampleRate: 48000,
		SentenceGapS: 0.35, TakeAttempts: 3, MinSPerLetter: 0.055, MaxSPerLetter: 0.25, MinTakeLUFS: -45,
	}
	return c
}

// Load reads path over the defaults; a missing file yields defaults.
// AUDIO_URL overrides worker.audio_url.
func Load(path string) (*Config, error) {
	c := Default()
	b, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		return nil, err
	}
	if err == nil {
		if err := yaml.Unmarshal(b, c); err != nil {
			return nil, fmt.Errorf("%s: %w", path, err)
		}
	}
	if v := os.Getenv("AUDIO_URL"); v != "" {
		c.Worker.AudioURL = v
	}
	return c, nil
}
