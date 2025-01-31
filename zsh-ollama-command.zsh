# default shortcut as Ctrl-o
(( ! ${+ZSH_OLLAMA_COMMANDS_HOTKEY} )) && typeset -g ZSH_OLLAMA_COMMANDS_HOTKEY='^o'
# default ollama model as llama3
(( ! ${+ZSH_OLLAMA_MODEL} )) && typeset -g ZSH_OLLAMA_MODEL='llama3'
# default response number as 5
(( ! ${+ZSH_OLLAMA_COMMANDS} )) && typeset -g ZSH_OLLAMA_COMMANDS='5'
# default ollama server host
(( ! ${+ZSH_OLLAMA_URL} )) && typeset -g ZSH_OLLAMA_URL='http://localhost:11434'

validate_required() {
  # check required tools are installed
  if (( ! $+commands[jq] )) then
      echo "🚨: zsh-ollama-command failed as jq NOT found!"
      echo "Please install it with 'brew install jq'"
      return 1;
  fi
  if (( ! $+commands[fzf] )) then
      echo "🚨: zsh-ollama-command failed as fzf NOT found!"
      echo "Please install it with 'brew install fzf'"
      return 1;
  fi
  if (( ! $+commands[curl] )) then
      echo "🚨: zsh-ollama-command failed as curl NOT found!"
      echo "Please install it with 'brew install curl'"
      return 1;
  fi
  if ! (( $(pgrep -f ollama | wc -l ) > 0 )); then
    echo "🚨: zsh-ollama-command failed as OLLAMA server NOT running!"
    echo "Please start it with 'brew services start ollama'"
    return 1;
  fi
  if ! curl -s "${ZSH_OLLAMA_URL}/api/tags" | grep -q $ZSH_OLLAMA_MODEL; then
    echo "🚨: zsh-ollama-command failed as model ${ZSH_OLLAMA_MODEL} server NOT found!"
    echo "Please start it with 'ollama pull ${ZSH_OLLAMA_MODEL}' or adjust ZSH_OLLAMA_MODEL"
    return 1;
  fi
}

check_status() {
  tput cuu 1 # cleanup waiting message
  if [ $? -ne 0 ]; then
    echo "༼ つ ◕_◕ ༽つ Sorry! Please try again..."
    exit 1
  fi
}

fzf_ollama_commands() {
  setopt extendedglob
  validate_required
  if [ $? -eq 1 ]; then
    return 1
  fi

  ZSH_OLLAMA_COMMANDS_USER_QUERY=$BUFFER

  zle end-of-line
  zle reset-prompt

  print
  print -u1 "👻Please wait..."

  ZSH_OLLAMA_COMMANDS_MESSAGE_CONTENT="Seeking OLLAMA for MacOS terminal commands for the following task: $ZSH_OLLAMA_COMMANDS_USER_QUERY. Reply with an array without newlines consisting solely of possible commands. The format would be like: ['command1; comand2;', 'command3&comand4;']. Response only contains array, no any additional description. No additional text should be present in each entry and commands, remove empty string entry. Each string entry should be a new string entry. If the task need more than one command, combine them in one string entry. Each string entry should only contain the command(s). Do not include empty entry. Provide multiple entry (at most $ZSH_OLLAMA_COMMANDS relevant entry) in response Json suggestions if available. Please ensure response can be parsed by jq"

  ZSH_OLLAMA_COMMANDS_REQUEST_BODY='{
    "model": "'$ZSH_OLLAMA_MODEL'",
    "messages": [
      {
        "role": "user",
        "content":  "'$ZSH_OLLAMA_COMMANDS_MESSAGE_CONTENT'"
      }
    ],
    "stream": false
  }'

  ZSH_OLLAMA_COMMANDS_RESPONSE=$(curl --silent "${ZSH_OLLAMA_URL}/api/chat" \
    -H "Content-Type: application/json" \
    -d "$ZSH_OLLAMA_COMMANDS_REQUEST_BODY")
  local ret=$?

  # trim response content newline
  ZSH_OLLAMA_COMMANDS_SUGGESTION=$(echo $ZSH_OLLAMA_COMMANDS_RESPONSE | tr -d '\n\r' | tr -d '\0' | jq '.')
  check_status

  # collect suggestion commands from response content
  ZSH_OLLAMA_COMMANDS_SUGGESTION=$(echo "$ZSH_OLLAMA_COMMANDS_SUGGESTION" | tr -d '\0' | jq -r '.message.content')
  check_status

  # Remove markdown code block markers
  ZSH_OLLAMA_COMMANDS_SUGGESTION="${ZSH_OLLAMA_COMMANDS_SUGGESTION//\`\`\`json/}"
  ZSH_OLLAMA_COMMANDS_SUGGESTION="${ZSH_OLLAMA_COMMANDS_SUGGESTION//\`\`\`/}"

  # attempts to extract suggestions from ZSH_OLLAMA_COMMANDS_SUGGESTION using jq.
  # If jq fails or returns no output, displays an error message and exits.
  # Otherwise, pipes the output to fzf for interactive selection
  ZSH_OLLAMA_COMMANDS_SELECTED=$(echo $ZSH_OLLAMA_COMMANDS_SUGGESTION | tr -d '\0' | jq -r '.[]')
  check_status

  tput cuu 1 # cleanup waiting message

  ZSH_OLLAMA_COMMANDS_SELECTED=$(echo $ZSH_OLLAMA_COMMANDS_SUGGESTION | jq -r '.[]' | fzf --ansi --height=~10 --cycle)
  BUFFER=$ZSH_OLLAMA_COMMANDS_SELECTED

  zle end-of-line
  zle reset-prompt
  return $ret
}

validate_required

autoload fzf_ollama_commands
zle -N fzf_ollama_commands

bindkey $ZSH_OLLAMA_COMMANDS_HOTKEY fzf_ollama_commands
