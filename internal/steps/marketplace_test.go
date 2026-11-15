package steps

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
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec"
)

// The shape `claude plugin marketplace list --json` prints (checked against claude 2.1.318).
const listedAIWarren = `[
  {"name": "ai-warren", "source": "directory", "path": "/test/marketplace", "installLocation": "/test/marketplace"}
]`

func TestMarketplaceStepIdempotent(t *testing.T) {
	ctx := context.Background()
	env, fake := testEnv(t, "linux")
	fake.Program("claude", "/usr/bin/claude")
	fake.OnOutput("/usr/bin/claude plugin marketplace list --json", listedAIWarren)
	step := &Marketplace{env: env}

	st, err := step.Check(ctx, testAnswers())
	require.NoError(t, err)
	assert.Equal(t, StatusOK, st)

	res, err := step.Apply(ctx, testAnswers())
	require.NoError(t, err)
	assert.False(t, res.Changed)
	assert.False(t, fake.Ran("/usr/bin/claude plugin marketplace add"), "an added marketplace is never added again")
}

func TestMarketplaceStepAdds(t *testing.T) {
	ctx := context.Background()
	env, fake := testEnv(t, "linux")
	env.MarketplaceSource = "/test/marketplace"
	fake.Program("claude", "/usr/bin/claude")
	listed := false
	fake.On("/usr/bin/claude plugin marketplace list --json", func(sysexec.Command, string) (sysexec.Result, error) {
		if listed {
			return sysexec.Result{Stdout: listedAIWarren}, nil
		}
		return sysexec.Result{Stdout: "[]\n"}, nil
	})
	fake.On("/usr/bin/claude plugin marketplace add /test/marketplace --json", func(sysexec.Command, string) (sysexec.Result, error) {
		listed = true
		return sysexec.Result{Stdout: `{"command":"marketplace-add","outcome":"ok","marketplace":"ai-warren","message":"Successfully added marketplace: ai-warren (declared in user settings)"}` + "\n"}, nil
	})
	step := &Marketplace{env: env}

	st, _ := step.Check(ctx, testAnswers())
	assert.Equal(t, StatusMissing, st)

	res, err := step.Apply(ctx, testAnswers())
	require.NoError(t, err)
	assert.True(t, res.Changed)
	assert.True(t, fake.Ran("/usr/bin/claude plugin marketplace add /test/marketplace --json"))

	st, err = step.Check(ctx, testAnswers())
	require.NoError(t, err)
	assert.Equal(t, StatusOK, st)
}

func TestMarketplaceStepDefaultSource(t *testing.T) {
	env, fake := testEnv(t, "linux")
	fake.Program("claude", "/usr/bin/claude")
	fake.OnOutput("/usr/bin/claude plugin marketplace list --json", "[]")
	fake.OnOutput("/usr/bin/claude plugin marketplace add the-rabbit-hole-tech/ai-warren --json", `{"outcome":"ok","marketplace":"ai-warren"}`)
	_, err := (&Marketplace{env: env}).Apply(context.Background(), testAnswers())
	require.NoError(t, err)
	assert.True(t, fake.Ran("/usr/bin/claude plugin marketplace add the-rabbit-hole-tech/ai-warren"))
}

func TestMarketplaceStepWrongName(t *testing.T) {
	env, fake := testEnv(t, "linux")
	fake.Program("claude", "/usr/bin/claude")
	fake.OnOutput("/usr/bin/claude plugin marketplace list --json", "[]")
	fake.OnOutput("/usr/bin/claude plugin marketplace add the-rabbit-hole-tech/ai-warren --json", `{"outcome":"ok","marketplace":"something-else"}`)
	_, err := (&Marketplace{env: env}).Apply(context.Background(), testAnswers())
	require.Error(t, err)
	assert.True(t, codes.Is(err, codes.StepFailed))
}

func TestMarketplaceStepUnknownMarketplace(t *testing.T) {
	env, fake := testEnv(t, "linux")
	fake.Program("claude", "/usr/bin/claude")
	fake.OnOutput("/usr/bin/claude plugin marketplace list --json", listedAIWarren)
	a := testAnswers()
	a.Marketplaces = []string{"ai-warren", "example-org"}
	_, err := (&Marketplace{env: env}).Apply(context.Background(), a)
	require.Error(t, err)
	assert.True(t, codes.Is(err, codes.MarketplaceUnknown))
}

func TestMarketplaceStepNeedsClaude(t *testing.T) {
	env, _ := testEnv(t, "linux")
	step := &Marketplace{env: env}
	st, err := step.Check(context.Background(), testAnswers())
	assert.Equal(t, StatusMissing, st)
	assert.True(t, codes.Is(err, codes.ClaudeMissing))
	_, err = step.Apply(context.Background(), testAnswers())
	assert.True(t, codes.Is(err, codes.ClaudeMissing))
}
