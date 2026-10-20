// Package config loads forge/config.yaml.
package config

import (
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

type Tone struct {
	Speed             float64 `yaml:"speed"`
	GainDB            float64 `yaml:"gain_db"`
	FallbackLowpassHz float64 `yaml:"fallback_lowpass_hz"`
}

type Voice struct {
	ID    string `yaml:"id"`
	Label string `yaml:"label"`
	Free  bool   `yaml:"free"`
	Ref   string `yaml:"ref"`
}

type Config struct {
	WorkDir string `yaml:"work_dir"`
	Python  struct {
		Cmd       []string `yaml:"cmd"`
		TTSWorker string   `yaml:"tts_worker"`
		QAWorker  string   `yaml:"qa_worker"`
	} `yaml:"python"`
	LLM struct {
		Temperature    float64 `yaml:"temperature"`
		MaxTokens      int     `yaml:"max_tokens"`
		TimeoutS       int     `yaml:"timeout_s"`
		Attempts       int     `yaml:"attempts"`
		GoldDir        string  `yaml:"gold_dir"`
		Template       string  `yaml:"template"`
		JudgeChecklist string  `yaml:"judge_checklist"`
	} `yaml:"llm"`
	TTS struct {
		Engine     string          `yaml:"engine"`
		SampleRate int             `yaml:"sample_rate"`
		GapS       float64         `yaml:"gap_s"`
		Tones      map[string]Tone `yaml:"tones"`
		Ramp       struct {
			Section  string  `yaml:"section"`
			SpeedTo  float64 `yaml:"speed_to"`
			GainToDB float64 `yaml:"gain_to_db"`
		} `yaml:"ramp"`
	} `yaml:"tts"`
	Voices []Voice `yaml:"voices"`
	Judge  struct {
		WPM                float64               `yaml:"wpm"`
		RefSpeed           float64               `yaml:"ref_speed"`
		LengthTolerance    float64               `yaml:"length_tolerance"`
		MaxSentenceWords   int                   `yaml:"max_sentence_words"`
		ForbiddenWordsFile string                `yaml:"forbidden_words_file"`
		LLM                string                `yaml:"llm"`
		LLMMinScore        float64               `yaml:"llm_min_score"`
		SectionBudgets10   map[string][2]float64 `yaml:"section_budgets_10min"`
	} `yaml:"judge"`
	Master struct {
		HighpassHz float64 `yaml:"highpass_hz"`
		LowpassHz  float64 `yaml:"lowpass_hz"`
		Deesser    string  `yaml:"deesser"`
		Reverb     string  `yaml:"reverb"`
		Aecho      string  `yaml:"aecho"`
		AfirIRS    float64 `yaml:"afir_ir_s"`
		AfirWet    float64 `yaml:"afir_wet"`
		LUFS       float64 `yaml:"lufs"`
		TruePeak   float64 `yaml:"true_peak"`
		LRA        float64 `yaml:"lra"`
		Bitrate    string  `yaml:"bitrate"`
	} `yaml:"master"`
	Ambient struct {
		CrossfadeS float64 `yaml:"crossfade_s"`
		LUFS       float64 `yaml:"lufs"`
		TruePeak   float64 `yaml:"true_peak"`
		LRA        float64 `yaml:"lra"`
		Bitrate    string  `yaml:"bitrate"`
	} `yaml:"ambient"`
	QA struct {
		WERMax          float64 `yaml:"wer_max"`
		WhisperModel    string  `yaml:"whisper_model"`
		Language        string  `yaml:"language"`
		SilenceMaxS     float64 `yaml:"silence_max_s"`
		SilenceDB       float64 `yaml:"silence_db"`
		ClipDBFS        float64 `yaml:"clip_dbfs"`
		HFCutoffHz      float64 `yaml:"hf_cutoff_hz"`
		HFMaxRelDB      float64 `yaml:"hf_max_rel_db"`
		LongPauseSlackS float64 `yaml:"long_pause_slack_s"`
	} `yaml:"qa"`
	Publish struct {
		BaseURL     string `yaml:"base_url"`
		DefaultFree bool   `yaml:"default_free"`
	} `yaml:"publish"`
	Nightly struct {
		QueueFile string `yaml:"queue_file"`
		Until     string `yaml:"until"`
		Timezone  string `yaml:"timezone"`
	} `yaml:"nightly"`
}

// Default returns the built-in configuration (mirrors config.yaml).
func Default() *Config {
	c := &Config{}
	c.WorkDir = "work"
	c.Python.Cmd = []string{"python3"}
	c.Python.TTSWorker = "python/tts_worker.py"
	c.Python.QAWorker = "python/qa_worker.py"
	c.LLM.Temperature = 0.7
	c.LLM.MaxTokens = 8000
	c.LLM.TimeoutS = 600
	c.LLM.Attempts = 2
	c.LLM.GoldDir = "scripts/gold"
	c.LLM.Template = "prompts/script_template.md"
	c.LLM.JudgeChecklist = "prompts/judge_checklist.md"
	c.TTS.Engine = "dummy"
	c.TTS.SampleRate = 48000
	c.TTS.GapS = 0.6
	c.TTS.Tones = map[string]Tone{
		"soft":    {Speed: 0.85, GainDB: 0},
		"slow":    {Speed: 0.78, GainDB: -3},
		"whisper": {Speed: 0.75, GainDB: -10, FallbackLowpassHz: 3500},
	}
	c.TTS.Ramp.Section = "dojezd"
	c.TTS.Ramp.SpeedTo = 0.75
	c.TTS.Ramp.GainToDB = -6
	c.Voices = []Voice{
		{ID: "mama", Label: "Měkký", Free: true, Ref: "voices/mama/ref.wav"},
		{ID: "tata", Label: "Hluboký", Free: true, Ref: "voices/tata/ref.wav"},
		{ID: "babicka", Label: "Vlídný", Free: false, Ref: "voices/babicka/ref.wav"},
	}
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
	c.Master.HighpassHz = 70
	c.Master.LowpassHz = 8000
	c.Master.Deesser = "deesser=i=0.4:m=0.5:f=0.5"
	c.Master.Reverb = "aecho"
	c.Master.Aecho = "aecho=0.9:0.85:19|31|47:0.10|0.07|0.04"
	c.Master.AfirIRS = 0.25
	c.Master.AfirWet = 0.12
	c.Master.LUFS = -23
	c.Master.TruePeak = -3
	c.Master.LRA = 20
	c.Master.Bitrate = "48k"
	c.Ambient.CrossfadeS = 4
	c.Ambient.LUFS = -30
	c.Ambient.TruePeak = -3
	c.Ambient.LRA = 11
	c.Ambient.Bitrate = "96k"
	c.QA.WERMax = 0.05
	c.QA.WhisperModel = "large-v3"
	c.QA.Language = "cs"
	c.QA.SilenceMaxS = 15
	c.QA.SilenceDB = -50
	c.QA.ClipDBFS = -0.1
	c.QA.HFCutoffHz = 10000
	c.QA.HFMaxRelDB = -35
	c.QA.LongPauseSlackS = 3
	c.Publish.BaseURL = "https://lioilsources.github.io/hajanek-content/"
	c.Nightly.QueueFile = "queue.txt"
	c.Nightly.Until = "07:00"
	c.Nightly.Timezone = "Europe/Prague"
	return c
}

// Load reads path over the defaults; a missing file yields defaults.
func Load(path string) (*Config, error) {
	c := Default()
	b, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return c, nil
		}
		return nil, err
	}
	if err := yaml.Unmarshal(b, c); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	if v := os.Getenv("FORGE_PYTHON"); v != "" {
		c.Python.Cmd = strings.Fields(v)
	}
	if v := os.Getenv("FORGE_TTS_ENGINE"); v != "" {
		c.TTS.Engine = v
	}
	return c, nil
}

func (c *Config) Voice(id string) (Voice, bool) {
	for _, v := range c.Voices {
		if v.ID == id {
			return v, true
		}
	}
	return Voice{}, false
}
