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

// RepoAnswers say which repo `warren step repo-settings` sets up and with which plugins.
type RepoAnswers struct {
	// Dir is the repo's top folder.
	Dir string `yaml:"dir" json:"dir"`
	// Visibility is the GitHub visibility: public, private or internal. A public repo keeps its
	// plugin settings local, so the private marketplace's name is never committed there.
	Visibility string `yaml:"visibility" json:"visibility"`
	// Plugins are the ai-warren plugins the repo uses, besides warren itself (always declared).
	Plugins []string `yaml:"plugins" json:"plugins"`
	// Marketplaces are extra marketplaces (an org's rules) by name, as owner/repo on GitHub.
	Marketplaces map[string]string `yaml:"marketplaces" json:"marketplaces"`
}

// Visibilities lists the values RepoAnswers.Visibility takes.
var Visibilities = []string{"public", "private", "internal"}
