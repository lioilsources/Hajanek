// Command forge is the Hajánek content pipeline (script → judge → publish) and the voice worker on Spark.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/lioilsources/hajanek/forge/internal/audio"
	"github.com/lioilsources/hajanek/forge/internal/jobs"
	"github.com/lioilsources/hajanek/forge/internal/pipeline"
	"github.com/lioilsources/hajanek/forge/internal/worker"
)

const usage = `forge — Hajánek content pipeline and voice worker

usage: forge <command> [flags]

commands:
  script   --tale ID --length N            generate content/scripts/{id}.{N}.md via LLM, then judge
  judge    [--length N] [--no-llm] FILE    check a script; JSON report, exit 1 on fail
  master-ambient [--crossfade S] IN OUT    seamless loop, −30 LUFS, Opus 96k stereo
  publish  --content-pages DIR [--commit]  copy reviewed/gold scripts + ambient, rebuild catalog.json
  nightly  [--queue FILE] [--until HH:MM]  drain script/publish jobs (api or queue file), publish, notify
  worker   [--once]                        voice jobs from hajanek-api → AiStack audio service (Spark)

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
	fs.BoolVar(&c.force, "force", false, "script: regenerate an existing script")
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
	tale   string
	length int
}

func addTrack(fs *flag.FlagSet, t *trackFlags) {
	fs.StringVar(&t.tale, "tale", "", "tale id")
	fs.IntVar(&t.length, "length", 10, "length in minutes")
}

func (t *trackFlags) check() {
	if t.tale == "" {
		die(fmt.Errorf("--tale is required"))
	}
}

func newWorker(e *pipeline.Env) (*worker.Worker, error) {
	api := jobs.FromEnv()
	if api == nil {
		return nil, fmt.Errorf("worker: FORGE_API_URL and WORKER_TOKEN are required")
	}
	wc := e.Cfg.Worker
	tmp := filepath.Join(e.Work, "_worker")
	if err := os.MkdirAll(tmp, 0o755); err != nil {
		return nil, err
	}
	clip := audio.ClipOpts{LUFS: wc.ClipLUFS, TruePeak: wc.ClipTruePeak, LRA: wc.ClipLRA, Bitrate: wc.ClipBitrate, SampleRate: wc.ClipSampleRate}
	return &worker.Worker{
		API:     api,
		Audio:   &worker.AudioClient{BaseURL: wc.AudioURL, Key: os.Getenv("AUDIO_API_KEY"), HTTP: &http.Client{Timeout: 2 * time.Minute}},
		Cfg:     wc,
		Prosody: e.Prosody(),
		Encode:  func(in, out string) (float64, error) { return audio.EncodeClip(in, out, clip) },
		TmpDir:  tmp,
		Log:     e.Log,
	}, nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	cmd, args := os.Args[1], os.Args[2:]
	fs := flag.NewFlagSet(cmd, flag.ExitOnError)
	var c common
	addCommon(fs, &c)
	var t trackFlags

	switch cmd {
	case "script":
		addTrack(fs, &t)
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

	case "nightly":
		queue := fs.String("queue", "", "queue file (default: config nightly.queue_file)")
		until := fs.String("until", "", "stop starting new jobs after HH:MM (default: config)")
		pages := fs.String("content-pages", os.Getenv("HAJANEK_PAGES_DIR"), "publish into this pages repo at the end")
		commit := fs.Bool("commit", false, "git commit in the pages repo")
		_ = fs.Parse(args)
		e := c.env()
		o := pipeline.NightlyOpts{QueueFile: e.Cfg.Nightly.QueueFile, Until: e.Cfg.Nightly.Until, Timezone: e.Cfg.Nightly.Timezone,
			PagesDir: *pages, Commit: *commit}
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

	case "worker":
		once := fs.Bool("once", false, "exit when the queue is empty (or a job is deferred)")
		_ = fs.Parse(args)
		w, err := newWorker(c.env())
		if err != nil {
			die(err)
		}
		if err := w.Run(ctx, *once); err != nil {
			die(err)
		}

	case "-h", "--help", "help":
		fmt.Print(usage)
	default:
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
}
