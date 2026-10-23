{
  "hooks": {
    "BeforeTool": [
      {
        "matcher": "write_file|replace|apply_patch|patch|edit",
        "hooks": [
          {
            "name": "harness-guard",
            "type": "command",
            "command": "$GEMINI_PROJECT_DIR/.harness/hooks/gemini/before-tool.sh",
            "timeout": 15000
          }
        ]
      }
    ],
    "AfterTool": [
      {
        "matcher": "write_file|replace|apply_patch|patch|edit",
        "hooks": [
          {
            "name": "harness-incremental",
            "type": "command",
            "command": "$GEMINI_PROJECT_DIR/.harness/hooks/gemini/after-tool.sh",
            "timeout": 60000
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "name": "harness-exit-gate",
            "type": "command",
            "command": "$GEMINI_PROJECT_DIR/.harness/hooks/gemini/session-end.sh",
            "timeout": 300000
          }
        ]
      }
    ]
  }
}