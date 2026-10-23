{
  "hooks": [
    {
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [
        {
          "type": "PreToolUse",
          "command": "bash .harness/hooks/pre-tool-use.sh",
          "timeout": 15
        },
        {
          "type": "PostToolUse",
          "command": "bash .harness/hooks/post-tool-use.sh",
          "timeout": 60
        }
      ]
    },
    {
      "matcher": "Stop",
      "hooks": [
        {
          "type": "Stop",
          "command": "bash .harness/hooks/stop.sh",
          "timeout": 300,
          "async": false
        }
      ]
    }
  ]
}
