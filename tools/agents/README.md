# Genesis Tools Agents

Project-local agents and wrappers that operate through tools in this directory.

## World Chat CLI Agent

Start the App, agent CLI, and debug dashboard first:

```bash
./scripts/start_agent_cli_dashboard.sh
```

The Codex agent in `.codex/agents/world-chat-cli-agent.toml` uses the
context-driven loop:

```bash
./tools/agent_cli/ctl agent world-chat-open --context-limit 40
./tools/agent_cli/ctl agent world-chat-send \
  --wid <WID> \
  --location-id <LOCATION_ID> \
  --message "<context-generated message>" \
  --reply-timeout-seconds 120 \
  --context-limit 60
```

`world-chat-open` lets the App select or enter the target and returns recent
chat context. `world-chat-send` sends exactly one message supplied by Codex and
returns the reply plus updated context for the next turn.

The shell wrapper below keeps the older App-generated batch automation:

```bash
bash tools/agents/run_world_chat_agent.sh --count 20
```

Specify a world and location when needed:

```bash
bash tools/agents/run_world_chat_agent.sh \
  --wid <WID> \
  --location-id <LOCATION_ID> \
  --count 20 \
  --location-count 3
```

Without `--wid`, the App picks a random eligible launched/joined world. Without
`--location-id`, the App picks a random leaf location.
