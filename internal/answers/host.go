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

// HostAnswers holds the values for this machine's host file. Every field is a plain value;
// secrets are never part of it.
type HostAnswers struct {
	// Path is where the host file is written. It defaults to <home>/.claude/CLAUDE.host.md.
	Path            string   `yaml:"path" json:"path"`
	Name            string   `yaml:"name" json:"name"`
	OS              string   `yaml:"os" json:"os"`
	Shell           string   `yaml:"shell" json:"shell"`
	ShellNotes      string   `yaml:"shell_notes" json:"shell_notes"`
	Timezone        string   `yaml:"timezone" json:"timezone"`
	CodeRoot        string   `yaml:"code_root" json:"code_root"`
	WorktreesDir    string   `yaml:"worktrees_dir" json:"worktrees_dir"`
	CredentialsDir  string   `yaml:"credentials_dir" json:"credentials_dir"`
	GitHost         string   `yaml:"git_host" json:"git_host"`
	GitAccount      string   `yaml:"git_account" json:"git_account"`
	GitName         string   `yaml:"git_name" json:"git_name"`
	GitEmail        string   `yaml:"git_email" json:"git_email"`
	CLIs            []string `yaml:"clis" json:"clis"`
	Hooks           []string `yaml:"hooks" json:"hooks"`
	OpsSession      string   `yaml:"ops_session" json:"ops_session"`
	CodingSession   string   `yaml:"coding_session" json:"coding_session"`
	Windows         []string `yaml:"windows" json:"windows"`
	ReviewWindows   []string `yaml:"review_windows" json:"review_windows"`
	WorkingHours    string   `yaml:"working_hours" json:"working_hours"`
	HandoffSite     string   `yaml:"handoff_site" json:"handoff_site"`
	HandoffPort     int      `yaml:"handoff_port" json:"handoff_port"`
	HandoffTestPort int      `yaml:"handoff_test_port" json:"handoff_test_port"`
	SetupDir        string   `yaml:"setup_dir" json:"setup_dir"`
	OwnerQueue      string   `yaml:"owner_queue" json:"owner_queue"`
	BugLogs         string   `yaml:"bug_logs" json:"bug_logs"`
	Holding         string   `yaml:"holding" json:"holding"`
	LaneScratch     string   `yaml:"lane_scratch" json:"lane_scratch"`
	LessonsLog      string   `yaml:"lessons_log" json:"lessons_log"`
	// MachineNotes, OrgFiles, Away, Weekends and SetupNotes add a machine's own facts to their
	// line; Notes are further host facts and Lessons the lessons that only make sense here.
	MachineNotes string   `yaml:"machine_notes" json:"machine_notes"`
	OrgFiles     string   `yaml:"org_files" json:"org_files"`
	Away         string   `yaml:"away" json:"away"`
	Weekends     string   `yaml:"weekends" json:"weekends"`
	SetupNotes   string   `yaml:"setup_notes" json:"setup_notes"`
	Notes        []string `yaml:"notes" json:"notes"`
	Lessons      []string `yaml:"lessons" json:"lessons"`
}

// Empty reports whether no host value was given, so the host step has nothing to do.
func (h HostAnswers) Empty() bool {
	return h.Name == "" && h.CodeRoot == "" && h.GitAccount == ""
}
