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

import "github.com/spf13/cobra"

// addMarketplaceSourceFlag adds --marketplace-source, which overrides where the ai-warren
// marketplace is added from (WARREN_MARKETPLACE_SOURCE does the same from the environment).
func addMarketplaceSourceFlag(cmd *cobra.Command, v *string) {
	cmd.Flags().StringVarP(v, "marketplace-source", "m", "",
		"Add the ai-warren marketplace from this source (owner/repo, git URL or local folder)")
}
