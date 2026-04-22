package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/HeaInSeo/kube-slint/pkg/slo/engine"
	"github.com/HeaInSeo/kube-slint/pkg/slo/fetch"
	"github.com/HeaInSeo/kube-slint/pkg/slo/spec"
	"github.com/HeaInSeo/kube-slint/pkg/slo/summary"
)

type fixture struct {
	RunID        string             `json:"runId"`
	StartedAt    time.Time          `json:"startedAt"`
	FinishedAt   time.Time          `json:"finishedAt"`
	Method       string             `json:"method"`
	Tags         map[string]string  `json:"tags"`
	Evidence     map[string]string  `json:"evidencePaths"`
	StartMetrics map[string]float64 `json:"startMetrics"`
	EndMetrics   map[string]float64 `json:"endMetrics"`
}

type staticFetcher struct {
	start fetch.Sample
	end   fetch.Sample
}

func (f *staticFetcher) Fetch(_ context.Context, at time.Time) (fetch.Sample, error) {
	if at.Equal(f.start.At) {
		return f.start, nil
	}
	return f.end, nil
}

func main() {
	inPath := flag.String("in", "", "path to VM-lab metrics fixture JSON")
	outPath := flag.String("out", "", "path to generated sli-summary.json")
	profile := flag.String("profile", "smoke", "spec profile: smoke or minimum")
	normalizeReliability := flag.Bool("normalize-reliability", true, "normalize replay-specific skew values in reliability output")
	flag.Parse()

	if *inPath == "" || *outPath == "" {
		fmt.Fprintln(os.Stderr, "-in and -out are required")
		os.Exit(2)
	}

	fix, err := loadFixture(*inPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "load fixture: %v\n", err)
		os.Exit(1)
	}

	specs, err := pickSpecs(*profile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "pick specs: %v\n", err)
		os.Exit(1)
	}

	fetcher := &staticFetcher{
		start: fetch.Sample{At: fix.StartedAt, Values: fix.StartMetrics},
		end:   fetch.Sample{At: fix.FinishedAt, Values: fix.EndMetrics},
	}
	writer := summary.NewJSONFileWriter()
	eng := engine.New(fetcher, writer, nil)

	method := engine.OutsideSnapshot
	if fix.Method != "" {
		method = engine.MeasurementMethod(fix.Method)
	}

	sum, err := engine.ExecuteStandard(context.Background(), eng, engine.ExecuteRequestStandard{
		Method: method,
		Config: engine.RunConfig{
			RunID:         fix.RunID,
			StartedAt:     fix.StartedAt,
			FinishedAt:    fix.FinishedAt,
			Tags:          fix.Tags,
			Format:        "v4",
			EvidencePaths: fix.Evidence,
		},
		Specs:       specs,
		OutPath:     *outPath,
		Reliability: &summary.Reliability{},
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "execute summary: %v\n", err)
		os.Exit(1)
	}
	if *normalizeReliability {
		normalizeReplayReliability(sum)
		if err := writer.Write(*outPath, *sum); err != nil {
			fmt.Fprintf(os.Stderr, "rewrite normalized summary: %v\n", err)
			os.Exit(1)
		}
	}

	fmt.Printf("generated summary: %s\n", *outPath)
	fmt.Printf("results=%d warnings=%d collection=%s evaluation=%s\n",
		len(sum.Results), len(sum.Warnings), sum.Reliability.CollectionStatus, sum.Reliability.EvaluationStatus)
}

func loadFixture(path string) (fixture, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return fixture{}, err
	}
	var f fixture
	if err := json.Unmarshal(data, &f); err != nil {
		return fixture{}, err
	}
	return f, nil
}

func pickSpecs(profile string) ([]spec.SLISpec, error) {
	switch profile {
	case "smoke":
		return spec.JUMIAHSmokeGuardrailSpecs(), nil
	case "minimum":
		return spec.JUMIAHMinimumSpecs(), nil
	default:
		return nil, fmt.Errorf("unknown profile %q", profile)
	}
}

func normalizeReplayReliability(sum *summary.Summary) {
	if sum == nil || sum.Reliability == nil {
		return
	}
	sum.Reliability.ConfigSourceType = "injected"
	sum.Reliability.ConfigSourcePath = "fixture_replay"
	sum.Reliability.StartSkewMs = nil
	sum.Reliability.EndSkewMs = nil
	if sum.Reliability.CollectionStatus == "Complete" && sum.Reliability.EvaluationStatus == "Complete" {
		score := 1.0
		sum.Reliability.ConfidenceScore = &score
	}
}
