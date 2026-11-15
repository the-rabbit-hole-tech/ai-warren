package answers

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
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
)

func writeConfig(t *testing.T, body string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "answers.yaml")
	require.NoError(t, os.WriteFile(path, []byte(body), 0o600))
	return path
}

const minimal = `version: 1
role: ops
github:
  login: someone
  name: someone
  email: 1+someone@users.noreply.github.com
`

func TestLoadExample(t *testing.T) {
	got, err := Load(filepath.Join("..", "..", "test", "container", "agent-machine.yaml"))
	require.NoError(t, err)

	want := Answers{
		Version: 1,
		Role:    "agent-machine",
		Tools:   []string{"tmux", "gh", "claude"},
		GitHub: GitHubAnswers{
			Login:    "testperson",
			Name:     "testperson",
			Email:    "1+testperson@users.noreply.github.com",
			TokenEnv: "GH_TOKEN",
			Signing:  "none",
			Guard:    "per-host",
		},
		Secrets:      SecretsAnswers{Enabled: false, URL: "", SecretPaths: []string{}},
		Marketplaces: []string{"ai-warren"},
		Plugins:      []string{"warren@ai-warren"},
		OrgPlugins:   []string{},
	}
	assert.Equal(t, want, got)
}

// The fake secrets are split so this file passes the pre-push scrub gate and the secret scan.
func TestLoadRejectsSecretValue(t *testing.T) {
	cases := map[string]string{
		"token field":        minimal + "  token: ghp_x\n",
		"password field":     minimal + "  password: hunter2\n",
		"key field":          minimal + "secrets:\n  key: abc\n",
		"api_secret field":   minimal + "secrets:\n  api_secret: abc\n",
		"github pat value":   minimal + "  signing: github_pat" + "_11AAAAAAA0abcdefghijkl\n",
		"anthropic value":    "version: 1\nrole: ops\ntools: [sk-" + "ant-api03-abcdefghijklmnop]\n",
		"gitlab value":       minimal + "org_plugins: [glpat" + "-abcdefghijklmnopqrst]\n",
		"aws key value":      minimal + "secrets:\n  url: AK" + "IAABCDEFGHIJKLMNOP\n",
		"private key header": minimal + "secrets:\n  url: \"-----BEGIN OPENSSH PRIVATE" + " KEY-----\"\n",
		"ghp in a list":      minimal + "plugins: [ghp" + "_abcdefghijklmnopqrstuvwxyz0123456789]\n",
	}
	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			_, err := Load(writeConfig(t, body))
			require.Error(t, err)
			assert.True(t, codes.Is(err, codes.ConfigSecret), "got %v", err)
			assert.Equal(t, "WARREN-CONFIG-SECRET", codes.Name(err))
			for _, secret := range []string{"ghp_x", "hunter2", "github_pat_11", "sk-ant-api03", "glpat-abc", "AKIAABCD", "ghp_abcdef"} {
				assert.NotContains(t, err.Error(), secret, "the error must never echo the value")
			}
		})
	}
}

func TestLoadAllowsSecretReferences(t *testing.T) {
	body := minimal + "  token_env: GH_TOKEN\nsecrets:\n  enabled: true\n  url: https://secrets.example.com\n  secret_paths: [dev/github/token]\n"
	got, err := Load(writeConfig(t, body))
	require.NoError(t, err)
	assert.Equal(t, "GH_TOKEN", got.GitHub.TokenEnv)
	assert.Equal(t, []string{"dev/github/token"}, got.Secrets.SecretPaths)
}

func TestLoadDefaults(t *testing.T) {
	got, err := Load(writeConfig(t, minimal))
	require.NoError(t, err)
	assert.Equal(t, DefaultTools, got.Tools)
	assert.Equal(t, []string{DefaultMarketplace}, got.Marketplaces)
	assert.Equal(t, []string{DefaultPlugin}, got.Plugins)
	assert.Equal(t, "none", got.GitHub.Signing)
	assert.Equal(t, "per-host", got.GitHub.Guard)
}

func TestLoadRejectsInvalid(t *testing.T) {
	cases := map[string]string{
		"unknown field":  minimal + "colour: blue\n",
		"bad version":    strings.Replace(minimal, "version: 1", "version: 2", 1),
		"bad role":       strings.Replace(minimal, "role: ops", "role: boss", 1),
		"bad signing":    minimal + "  signing: gpg\n",
		"not yaml":       "version: [1\n",
		"guard not host": minimal + "  guard: shared\n",
	}
	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			_, err := Load(writeConfig(t, body))
			require.Error(t, err)
			assert.True(t, codes.Is(err, codes.ConfigInvalid), "got %v", err)
		})
	}
}

func TestLoadMissingFile(t *testing.T) {
	_, err := Load(filepath.Join(t.TempDir(), "nope.yaml"))
	require.Error(t, err)
	assert.True(t, codes.Is(err, codes.ConfigInvalid))
}

func TestFromJSON(t *testing.T) {
	in := `{"version":1,"role":"ops","github":{"login":"someone","name":"someone","email":"e@example.com","token_env":"GH_TOKEN"},"plugins":["warren@ai-warren"]}`
	got, err := FromJSON(strings.NewReader(in))
	require.NoError(t, err)
	assert.Equal(t, "someone", got.GitHub.Login)
	assert.Equal(t, "GH_TOKEN", got.GitHub.TokenEnv)
	assert.Equal(t, DefaultTools, got.Tools)
}

func TestFromJSONRejectsSecret(t *testing.T) {
	in := `{"version":1,"role":"ops","github":{"login":"someone","token":"ghp_abc"}}`
	_, err := FromJSON(strings.NewReader(in))
	require.Error(t, err)
	assert.True(t, codes.Is(err, codes.ConfigSecret))
	assert.NotContains(t, err.Error(), "ghp_abc")
}

func TestSaveRoundTrip(t *testing.T) {
	a, err := Load(filepath.Join("..", "..", "test", "container", "agent-machine.yaml"))
	require.NoError(t, err)
	path := filepath.Join(t.TempDir(), "nested", "answers.json")
	require.NoError(t, Save(path, a))
	got, err := FromJSONFile(path)
	require.NoError(t, err)
	assert.Equal(t, a, got)
	fi, err := os.Stat(path)
	require.NoError(t, err)
	assert.Equal(t, os.FileMode(0o600), fi.Mode().Perm())
}
