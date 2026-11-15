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
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
)

func TestFromJSONReadsHostAnswers(t *testing.T) {
	a, err := FromJSON(strings.NewReader(`{"version":1,"host":{"name":"box","code_root":"/code","handoff_port":8080,"clis":["gh"]}}`))
	require.NoError(t, err)
	assert.Equal(t, "box", a.Host.Name)
	assert.Equal(t, 8080, a.Host.HandoffPort)
	assert.False(t, a.Host.Empty())
	assert.True(t, Answers{}.Host.Empty())
}

func TestHostAnswersRejectSecretLookingValues(t *testing.T) {
	cases := map[string]string{
		"token value in a field":   `{"version":1,"host":{"name":"ghp` + `_abcdefghijklmnop"}}`,
		"anthropic key in notes":   `{"version":1,"host":{"shell_notes":"sk-` + `ant-api03-abcdefghijkl"}}`,
		"private key in a list":    `{"version":1,"host":{"clis":["-----BEGIN RSA PRIVATE` + ` KEY-----"]}}`,
		"password-named host key":  `{"version":1,"host":{"password":"hunter2"}}`,
		"credentials folder value": `{"version":1,"host":{"credentials_dir":"glpat` + `-abcdefghijklmnopqrst"}}`,
	}
	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			_, err := FromJSON(strings.NewReader(body))
			require.Error(t, err)
			assert.NotContains(t, err.Error(), "hunter2")
			assert.NotContains(t, err.Error(), "abcdefghijkl")
		})
	}
	_, err := FromJSON(strings.NewReader(`{"version":1,"host":{"password":"x"}}`))
	assert.True(t, codes.Is(err, codes.ConfigSecret) || codes.Is(err, codes.ConfigInvalid))
}

func TestHostCredentialsFolderPathIsAllowed(t *testing.T) {
	_, err := FromJSON(strings.NewReader(`{"version":1,"host":{"credentials_dir":"/opt/example/keys"}}`))
	require.NoError(t, err)
}
