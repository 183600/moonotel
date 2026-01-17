# Vibe Coding Automation Setup

## Overview

This automation system continuously runs the `vibe_coding.sh` script to manage multiple MoonBit repositories with AI-powered development assistance.

## Configuration

### Method 1: External Configuration File (Recommended)

Create a configuration file at `~/.vibe_coding_repos.conf`:

```bash
#!/usr/bin/env bash
REPO_LIST=(
  "Feather|<gitee-url>|<github-url>|<api-url>|<api-key>|<model>|<auth-type>"
  "moonotel|<gitee-url>|<github-url>|<api-url>|<api-key>|<model>|<auth-type>"
)
```

This file is automatically loaded by `vibe_coding.sh` and should NOT be committed to git.

### Method 2: Direct Configuration

Alternatively, edit the REPO_LIST array in `/home/engine/project/scripts/vibe_coding.sh` directly (lines 19-26).

### Configuration Format

Each repository entry follows this format:
```
"Name|GiteeCloneURL|GitHubPushURL|BaseURL|APIKey|ModelName|AuthType"
```

- **Name**: Local directory name for the repository
- **GiteeCloneURL**: Gitee repository URL (with credentials) to clone from
- **GitHubPushURL**: GitHub repository URL (with credentials) to push to
- **BaseURL**: API endpoint for AI service (e.g., NVIDIA, Groq)
- **APIKey**: API key for authentication
- **ModelName**: AI model to use
- **AuthType**: Authentication type (typically "openai-compatible")

## Running the Automation

### Current Status

The automation is currently running in the background:
- Process ID: Check with `ps aux | grep vibe_coding`
- Main log: `/tmp/vibe_coding_runner.log`
- Repository logs: `/tmp/iflow_repos/<RepoName>.log`

### Starting the Automation

```bash
cd /home/engine/project
nohup bash run_vibe_coding.sh > /tmp/vibe_coding_runner.log 2>&1 &
```

### Stopping the Automation

```bash
pkill -f "vibe_coding"
```

### Restarting the Automation

```bash
pkill -f "vibe_coding"
sleep 2
cd /home/engine/project
nohup bash run_vibe_coding.sh > /tmp/vibe_coding_runner.log 2>&1 &
```

## Repository Workspace

All repositories are cloned and managed in:
```
/tmp/iflow_repos/
├── Feather/          # Feather repository
│   └── <source files>
├── Feather.log       # Feather worker log
├── moonotel/         # moonotel repository
│   └── <source files>
└── moonotel.log      # moonotel worker log
```

## Monitoring

### View Main Runner Log
```bash
tail -f /tmp/vibe_coding_runner.log
```

### View Repository Worker Logs
```bash
# Feather repository
tail -f /tmp/iflow_repos/Feather.log

# moonotel repository
tail -f /tmp/iflow_repos/moonotel.log
```

### Check Process Status
```bash
ps aux | grep vibe_coding
```

## How It Works

1. **Initialization**: `run_vibe_coding.sh` starts `vibe_coding.sh`
2. **Repository Setup**: Clones/updates all configured repositories from Gitee
3. **Worker Processes**: Spawns a worker process for each repository
4. **Continuous Loop**: Each worker runs in a 5-hour loop (configurable via `RUN_HOURS`)
   - Runs `moon test`
   - If tests pass: Adds new test cases via iFlow
   - If tests fail: Fixes issues via iFlow
   - Commits changes
   - Pushes to both Gitee and GitHub
5. **Auto-Restart**: If a worker exits, it automatically restarts after 60 seconds

## Environment Variables

Key environment variables (set in `vibe_coding.sh`):

- `BASE_DIR`: Repository workspace directory (default: `/tmp/iflow_repos`)
- `RUN_HOURS`: Duration of each work loop (default: `5`)
- `WORK_BRANCH`: Git branch to work on (default: `master`)
- `GIT_USER_NAME`: Git commit author name (default: `iflow-bot`)
- `GIT_USER_EMAIL`: Git commit author email
- `ENABLE_RELEASE`: Enable automatic version bumping and GitHub releases (default: `0`)
- `AUTO_COMMIT_ON_TIMEOUT`: Auto-commit changes when loop times out (default: `1`)

## Customization

To modify the repository list or configuration:

1. Stop the automation: `pkill -f "vibe_coding"`
2. Edit `~/.vibe_coding_repos.conf` (or create it if it doesn't exist)
3. Update the `REPO_LIST` array with your repositories
4. Restart the automation as described above

**Security Note**: Never commit `~/.vibe_coding_repos.conf` to git as it contains sensitive credentials!

## Troubleshooting

### Repositories not cloning
- Check network connectivity to Gitee
- Verify credentials in the repository URLs

### iFlow API errors
- Check API key validity
- Verify API endpoint URL
- Review repository log files for specific error messages

### Script keeps restarting
- Check main log: `tail -100 /tmp/vibe_coding_runner.log`
- Look for error messages indicating why the script exited

## Notes

- The automation uses AI (via iFlow) to automatically fix code issues and add tests
- Each repository has its own isolated worker process and log file
- Commits are automatically pushed to both Gitee (origin) and GitHub (github remote)
- The system is designed to run indefinitely with automatic restarts
