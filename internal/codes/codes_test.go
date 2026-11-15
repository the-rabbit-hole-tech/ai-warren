package codes

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
	"errors"
	"fmt"
	"testing"

	"github.com/Bugs5382/go-apperr"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewCarriesCodeAndName(t *testing.T) {
	err := New(ConfigSecret, "github.%s holds a literal value", "token")

	num, ok := apperr.Code(err)
	require.True(t, ok)
	assert.Equal(t, ConfigSecret.Num, num)
	assert.Equal(t, "WARREN-CONFIG-SECRET", Name(err))
	assert.True(t, Is(err, ConfigSecret))
	assert.False(t, Is(err, GuardNoIdentity))
	assert.Equal(t, "WARREN-CONFIG-SECRET: github.token holds a literal value", err.Error())
}

func TestWrapKeepsCause(t *testing.T) {
	cause := errors.New("boom")
	err := Wrap(StepFailed, cause, "tools")

	assert.ErrorIs(t, err, cause)
	assert.True(t, Is(fmt.Errorf("outer: %w", err), StepFailed))
	assert.Contains(t, err.Error(), "WARREN-STEP-FAILED: tools: boom")
}

func TestNameOfUncodedError(t *testing.T) {
	assert.Empty(t, Name(errors.New("plain")))
	assert.Empty(t, Name(nil))
}

func TestRegistryBuilds(t *testing.T) {
	reg, err := Registry()
	require.NoError(t, err)
	for _, c := range All {
		e, ok := reg.Describe(c.Num)
		require.True(t, ok, c.Name)
		assert.NotEmpty(t, e.Symbol)
	}
}
