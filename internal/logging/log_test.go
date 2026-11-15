package logging

/*
Apache License 2.0

Copyright 2026 The ai-warren Authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"

	golog "github.com/Bugs5382/go-log"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestBuildLevels(t *testing.T) {
	t.Run("verbose is trace", func(t *testing.T) {
		t.Setenv("LOG_LEVEL", "")
		t.Setenv("LOG_FORMAT", "")
		var buf bytes.Buffer
		build(true, &buf).Trace("trace line")
		assert.Contains(t, buf.String(), "trace line")
	})
	t.Run("default is info", func(t *testing.T) {
		t.Setenv("LOG_LEVEL", "")
		t.Setenv("LOG_FORMAT", "")
		var buf bytes.Buffer
		l := build(false, &buf)
		l.Debug("debug line")
		l.Info("info line")
		assert.NotContains(t, buf.String(), "debug line")
		assert.Contains(t, buf.String(), "info line")
	})
	t.Run("LOG_LEVEL wins over verbose", func(t *testing.T) {
		t.Setenv("LOG_LEVEL", "warn")
		t.Setenv("LOG_FORMAT", "")
		var buf bytes.Buffer
		l := build(true, &buf)
		l.Info("info line")
		assert.NotContains(t, buf.String(), "info line")
	})
}

func TestBuildFormat(t *testing.T) {
	t.Run("console by default", func(t *testing.T) {
		t.Setenv("LOG_LEVEL", "")
		t.Setenv("LOG_FORMAT", "")
		var buf bytes.Buffer
		build(false, &buf).Info("hello")
		assert.False(t, strings.HasPrefix(strings.TrimSpace(buf.String()), "{"))
	})
	t.Run("json on request", func(t *testing.T) {
		t.Setenv("LOG_LEVEL", "")
		t.Setenv("LOG_FORMAT", "json")
		var buf bytes.Buffer
		build(false, &buf).Info("hello")
		var line map[string]any
		require.NoError(t, json.Unmarshal(buf.Bytes(), &line))
		assert.Equal(t, "warren", line["service"])
	})
}

func TestUse(t *testing.T) {
	var buf bytes.Buffer
	Use(golog.NewLoggerWithOptions("warren", golog.WithOutput(&buf), golog.WithDefaultLevel(golog.LevelTrace)))
	t.Cleanup(func() { Init(false) })
	L().Info("captured")
	assert.Contains(t, buf.String(), "captured")
}
