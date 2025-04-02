# gpt.nu

Integrate LLM providers into Nushell pipelines

```nu
# Define a system prompt and ask a question
[{
  role: "system"
  content: "You are a direct assistant. Provide concise answers without elaboration or follow-up questions."
},
{
  role: "user"
  content: "What's 4 + 4?"
}] | gpt call
```

## Practical Examples

```nu
# Process a file through an LLM
open README.md | str join | wrap content | wrap {role: "user"} | gpt call | save summary.txt

# Stream responses in real-time
[{role: "user", content: "Write a short poem about coding"}] | gpt call --streamer {|| print -n $in}

# Chain with other Nushell commands
[{role: "user", content: "List 5 popular Linux distros"}] | gpt call | lines | where {|line| $line =~ "Ubuntu"}
```

## Features

- Unified interface for multiple LLM providers
- Current providers: OpenAI, Anthropic, Cerebras, Gemini (@eggcaker 🙏)
- Streaming responses support
- Easy provider configuration and switching
- [Easy to add new providers](#adding-a-new-provider)

## Installation

```nu
"https://raw.githubusercontent.com/cablehead/gpt.nu/refs/heads/main/gpt.nu" | each {|url| http get $url | save ($url | path basename) }
use gpt.nu *
```

## Getting Started

Before using gpt.nu, you need to select a provider and model:

```nu
gpt select-provider
```

This interactive command will:
1. Let you choose from available providers
2. Prompt for the required API key if not already set
3. Show available models for your chosen provider

After selecting a provider, you can start using the examples shown above.

## Programmatic Provider Configuration

Instead of using the interactive selector, you can configure your provider
directly:

```nu
# As a record
$env.GPT_PROVIDER = {
    name: openai
    model: "gpt-4"
}

# Or as a JSON string
$env.GPT_PROVIDER = '{"name": "openai", "model": "gpt-4"}'
```

You can also set API keys directly:

```nu
$env.OPENAI_API_KEY = "sk-..."
$env.ANTHROPIC_API_KEY = "sk-ant-..."
$env.CEREBRAS_API_KEY = "sk-..."
$env.GEMINI_API_KEY = "..."
```

## Message Format

The `gpt call` command expects a list of message records, where each message has
a `role` and `content` field. There are three possible roles:

- `system`: Sets behavior and constraints for the LLM
- `user`: Contains the user's input
- `assistant`: Contains previous responses from the LLM

You can build message lists using Nushell's append command, which is
particularly useful for loading stored system prompts:

```nu
# You can combine messages from different sources
# First create a system prompt
let system_prompt = {
    role: "system"
    content: "You are a coding assistant specialized in writing clear, efficient code."
}

# Then add a user message and make the call
$system_prompt | append {
    role: "user"
    content: "Write a function that calculates the Fibonacci sequence"
} | gpt call
```

## Response Streaming

By default, `gpt call` sends its complete response through the Nushell pipeline:

```nu
> [{role: "user" content: "Explain streams"}] | gpt call | save response.txt  # Works silently
```

Use the optional `--streamer` flag to monitor the response while it's being
generated:

```nu
> [{role: "user" content: "Explain streams"}] | gpt call --streamer {|| print -n $in} | save response.txt
This is the response being printed... # Shown in real-time
While also saving the complete response to response.txt
```

The streamer closure is called with small snippets of the response, as they are
generated, and can present them however you like. In this example we're just
printing to the terminal.

## Command Reference

### `gpt call`

Make a call to the configured LLM provider.

```nu
# Input type: list<record<role: string, content: string>>
# Output type: string
```

### `gpt select-provider`

Interactively select a provider and model. Will prompt for API key if not set.

### `gpt models`

List available models for the current provider.

```nu
# Output type: table<id: string, created: datetime>
```

## Adding a New Provider

To add support for a new LLM provider, implement two functions in the
`GPT_PROVIDERS` environment record:

```nu
$env.GPT_PROVIDERS = {
    example_provider: {
        # List available models
        # Must return table with 'id' and 'created' columns
        models: {||
            [[
                [id, created];
                ["gpt-x", ("2024-01-01" | into datetime)]
                ["gpt-y", ("2023-12-01" | into datetime)]
            ]]
        }

        # Handle LLM calls
        # Input: list<record<role: string, content: string>>
        # Output: streamed response chunks
        call: {|model: string|
            let data = {
                model: $model
                stream: true
                messages: $in
            }

            http post https://api.example.com/v1/chat
            -H { Authorization: $"Bearer ($env.EXAMPLE_API_KEY)" }
            $data
            | lines
            | each {|line| parse_content $line}
        }
    }
}
```

## Contributing

Contributions are welcome! Particularly new provider implementations. Please
feel free to submit a Pull Request.

## License

MIT
