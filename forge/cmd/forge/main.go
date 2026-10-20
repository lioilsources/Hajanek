// Command forge is the Hajánek generation pipeline (script → voice → master → qa → publish).
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strings"

	"github.com/lioilsources/hajanek/forge/internal/pipeline"
)

const usage = `forge — Hajánek generation pipeline

usage: forge <command> [flags]

commands:
  script   --tale ID --length N            generate content/scripts/{id}.{N}.md via LLM, then judge
  judge    [--length N] [--no-llm] FILE    check a script; JSON report, exit 1 on fail
  voice    --tale ID --voice V --length N  TTS per utterance (cached) + assembly → voice.wav
  master   --tale ID --voice V --length N  ffmpeg mastering → master.opus (−23 LUFS, Opus 48k mono)
  master-ambient [--crossfade S] IN OUT    seamless loop, −30 LUFS, Opus 96k stereo
  qa       --tale ID --voice V --length N  ASR WER + signal checks → qa.json
  publish  --content-pages DIR [--commit]  copy passing tracks, merge catalog.json
  run      --tale ID --voice V --length N  all of the above, stops on judge/qa failure
  nightly  [--queue FILE] [--until HH:MM]  drain hajanek-api jobs or queue file, publish, notify

common flags: --repo DIR --content DIR --config FILE --force
`

type common struct {
	repo, content, config string
	force                 bool
}

func addCommon(fs *flag.FlagSet, c *common) {
	fs.StringVar(&c.repo, "repo", "", "monorepo root (default: auto-detect)")
	fs.StringVar(&c.content, "content", "", "content dir (default: {repo}/content)")
	fs.StringVar(&c.config, "config", "", "config file (default: {repo}/forge/config.yaml)")
	fs.BoolVar(&c.force, "force", false, "redo even if outputs are up to date")
}

func (c *common) env() *pipeline.Env {
	repo := c.repo
	if repo == "" {
		wd, _ := os.Getwd()
		r, err := pipeline.FindRepo(wd)
		if err != nil {
			die(err)
		}
		repo = r
	}
	e, err := pipeline.NewEnv(repo, c.content, c.config)
	if err != nil {
		die(err)
	}
	e.Force = c.force
	return e
}

func die(err error) {
	fmt.Fprintln(os.Stderr, "forge:", err)
	os.Exit(1)
}

func printJSON(v any) {
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	_ = enc.Encode(v)
}

type trackFlags struct {
	tale, voice string
	length      int
}

func addTrack(fs *flag.FlagSet, t *trackFlags, needVoice bool) {
	fs.StringVar(&t.tale, "tale", "", "tale id")
	fs.IntVar(&t.length, "length", 10, "length in minutes")
	if needVoice {
		fs.StringVar(&t.voice, "voice", "mama", "voice id")
	}
}

func (t *trackFlags) check() {
	if t.tale == "" {
		die(fmt.Errorf("--tale is required"))
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	cmd, args := os.Args[1], os.Args[2:]
	fs := flag.NewFlagSet(cmd, flag.ExitOnError)
	var c common
	addCommon(fs, &c)
	var t trackFlags

	switch cmd {
	case "script":
		addTrack(fs, &t, false)
		_ = fs.Parse(args)
		t.check()
		e := c.env()
		_, rep, err := e.GenerateScript(ctx, pipeline.ScriptOpts{Tale: t.tale, Length: t.length})
		if rep != nil {
			printJSON(rep)
		}
		if err != nil {
			die(err)
		}
		if !rep.OK {
			os.Exit(1)
		}

	case "judge":
		length := fs.Int("length", 0, "target length (default: front matter length_min)")
		noLLM := fs.Bool("no-llm", false, "deterministic checks only")
		_ = fs.Parse(args)
		if fs.NArg() != 1 {
			die(fmt.Errorf("usage: forge judge [--length N] FILE"))
		}
		e := c.env()
		rep, err := e.Judge(ctx, fs.Arg(0), *length, !*noLLM)
		if err != nil {
			die(err)
		}
		printJSON(rep)
		if !rep.OK {
			os.Exit(1)
		}

	case "voice":
		addTrack(fs, &t, true)
		allow := fs.Bool("allow-draft", false, "voice scripts with status: draft")
		_ = fs.Parse(args)
		t.check()
		m, err := c.env().Voice(pipeline.VoiceOpts{Tale: t.tale, Voice: t.voice, Length: t.length, AllowDraft: *allow})
		if err != nil {
			die(err)
		}
		printJSON(map[string]any{"duration_s": m.DurationS, "synthesized": m.Synthesize, "cache_hits": m.CacheHits, "silences": len(m.Silences)})

	case "master":
		addTrack(fs, &t, true)
		_ = fs.Parse(args)
		t.check()
		rep, err := c.env().Master(t.tale, t.voice, t.length)
		if rep != nil {
			printJSON(rep.Result.Measured)
		}
		if err != nil {
			die(err)
		}

	case "master-ambient":
		xf := fs.Float64("crossfade", 0, "crossfade seconds (default: config)")
		_ = fs.Parse(args)
		if fs.NArg() != 2 {
			die(fmt.Errorf("usage: forge master-ambient IN OUT"))
		}
		e := c.env()
		if *xf > 0 {
			e.Cfg.Ambient.CrossfadeS = *xf
		}
		res, err := e.MasterAmbient(fs.Arg(0), fs.Arg(1))
		if err != nil {
			die(err)
		}
		printJSON(map[string]any{"measured": res.Measured, "probe": res.Probe})

	case "qa":
		addTrack(fs, &t, true)
		_ = fs.Parse(args)
		t.check()
		rep, err := c.env().QA(t.tale, t.voice, t.length)
		if rep != nil {
			printJSON(rep)
		}
		if err != nil {
			die(err)
		}

	case "publish":
		pages := fs.String("content-pages", os.Getenv("HAJANEK_PAGES_DIR"), "pages repo dir (hajanek-content)")
		commit := fs.Bool("commit", false, "git commit in the pages repo")
		_ = fs.Parse(args)
		if *pages == "" {
			die(fmt.Errorf("--content-pages is required"))
		}
		res, err := c.env().Publish(pipeline.PublishOpts{PagesDir: *pages, Commit: *commit})
		if res != nil {
			printJSON(res)
		}
		if err != nil {
			die(err)
		}

	case "run":
		addTrack(fs, &t, true)
		allow := fs.Bool("allow-draft", false, "voice scripts with status: draft")
		pages := fs.String("content-pages", os.Getenv("HAJANEK_PAGES_DIR"), "publish into this pages repo (optional)")
		commit := fs.Bool("commit", false, "git commit in the pages repo")
		_ = fs.Parse(args)
		t.check()
		r := c.env().Run(ctx, pipeline.RunOpts{Tale: t.tale, Voice: t.voice, Length: t.length,
			AllowDraft: *allow, PagesDir: *pages, Commit: *commit})
		printJSON(r)
		if !r.OK {
			os.Exit(1)
		}

	case "nightly":
		queue := fs.String("queue", "", "queue file (default: config nightly.queue_file)")
		until := fs.String("until", "", "stop starting new jobs after HH:MM (default: config)")
		allow := fs.Bool("allow-draft", false, "voice scripts with status: draft")
		pages := fs.String("content-pages", os.Getenv("HAJANEK_PAGES_DIR"), "publish into this pages repo at the end")
		commit := fs.Bool("commit", false, "git commit in the pages repo")
		_ = fs.Parse(args)
		e := c.env()
		o := pipeline.NightlyOpts{QueueFile: e.Cfg.Nightly.QueueFile, Until: e.Cfg.Nightly.Until, Timezone: e.Cfg.Nightly.Timezone,
			AllowDraft: *allow, PagesDir: *pages, Commit: *commit}
		if *queue != "" {
			o.QueueFile = *queue
		}
		if *until != "" {
			o.Until = *until
		}
		if strings.EqualFold(o.Until, "none") {
			o.Until = ""
		}
		rs, err := e.Nightly(ctx, o)
		printJSON(rs)
		if err != nil {
			die(err)
		}
		for _, r := range rs {
			if !r.OK {
				os.Exit(1)
			}
		}

	case "-h", "--help", "help":
		fmt.Print(usage)
	default:
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
}
