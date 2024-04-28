# default shortcut as Ctrl-o
(( ! ${+ZSH_OLLAMA_COMMANDS_HOTKEY} )) && typeset -g ZSH_OLLAMA_COMMANDS_HOTKEY='^o'
# default ollama model as llama3
(( ! ${+ZSH_OLLAMA_MODEL} )) && typeset -g ZSH_OLLAMA_MODEL='llama3'

validate_required() {
  # check required tools are installed
  if (( ! $+commands[jq] )) then
      echo "🚨: zsh-ollama-command failed as jq NOT found!"
      echo "Please install it with 'brew install jq'"
      return;
  fi
  if (( ! $+commands[fzf] )) then
      echo "🚨: zsh-ollama-command failed as fzf NOT found!"
      echo "Please install it with 'brew install fzf'"
      return;
  fi
  if (( ! $+commands[curl] )) then
      echo "🚨: zsh-ollama-command failed as curl NOT found!"
      echo "Please install it with 'brew install curl'"
      return;
  fi
  if ! (( $(pgrep -f ollama | wc -l ) > 0 )); then
    echo "🚨: zsh-ollama-command failed as OLLAMA server NOT running!"
    echo "Please start it with 'brew services start ollama'"
    return;
  fi
}

fzf_ollama_commands() {
  setopt extendedglob

  ZSH_OLLAMA_COMMANDS_USER_QUERY=$BUFFER

  # TODO: For some reason the buffer is only updated if zsh-autosuggestions is enabled
  BUFFER="Please wait..."
  zle end-of-line
  zle reset-prompt

  ZSH_OLLAMA_COMMANDS_MESSAGE_CONTENT="Seeking OLLAMA for MacOS terminal commands for the following task: $ZSH_OLLAMA_COMMANDS_USER_QUERY. Reply with an array without newlines consisting solely of possible commands. The format would be like: ['command1; comand2;', 'command3&comand4;']. Response only contains array, no any additional description. No additional text should be present in each entry and commands, remove empty string entry. Each string entry should be a new string entry. If the task need more than one command, combine them in one string entry. Each string entry should only contain the command(s). Do not include empty entry. Provide multiple entry (at most 5 relevant entry) in response Json suggestions if available. Please ensure response can be parsed by jq"

  ZSH_OLLAMA_COMMANDS_REQUEST_BODY='{
    "model": "llama3",
    "messages": [
      {
        "role": "user",
        "content":  "'$ZSH_OLLAMA_COMMANDS_MESSAGE_CONTENT'"
      }
    ],
    "stream": false
  }'

  ZSH_OLLAMA_COMMANDS_RESPONSE=$(curl --silent http://localhost:11434/api/chat \
    -H "Content-Type: application/json" \
    -d "$ZSH_OLLAMA_COMMANDS_REQUEST_BODY")
  local ret=$?

  # trim response content newline
  ZSH_OLLAMA_COMMANDS_SUGGESTION=$(echo $ZSH_OLLAMA_COMMANDS_RESPONSE | tr -d '\n\r' | tr -d '[:space:]' | tr -d '\0' | jq '.')

  # collect suggestion commands from response content
  ZSH_OLLAMA_COMMANDS_SUGGESTION=$(echo "$ZSH_OLLAMA_COMMANDS_SUGGESTION" | tr -d '\0' | jq -r '.message.content')

  # attempts to extract suggestions from ZSH_OLLAMA_COMMANDS_SUGGESTION using jq.
  # If jq fails or returns no output, displays an error message and exits.
  # Otherwise, pipes the output to fzf for interactive selection
  ZSH_OLLAMA_COMMANDS_SELECTED=$(echo $ZSH_OLLAMA_COMMANDS_SUGGESTION | tr -d '\0' | jq -r '.[]' | fzf --ansi --height=~10 --cycle)
  BUFFER=$ZSH_OLLAMA_COMMANDS_SELECTED

  zle end-of-line
  zle reset-prompt
  return $ret
}

validate_required

autoload fzf_ollama_commands
zle -N fzf_ollama_commands

bindkey $ZSH_OLLAMA_COMMANDS_HOTKEY fzf_ollama_commands

