package commands

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
	"fmt"

	buildinfo "github.com/Bugs5382/go-buildinfo"
	"github.com/spf13/cobra"
)

// VersionCmd builds `warren version`, fed from the build stamp go-buildinfo reads.
func VersionCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "Print the warren version and commit",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			info := buildinfo.Get()
			_, err := fmt.Fprintf(cmd.OutOrStdout(), "%s\ncommit %s\n%s\n", info.Version, info.Commit, info.GoVersion)
			return err
		},
	}
}
