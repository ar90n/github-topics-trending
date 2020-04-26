#!/bin/sh

curl -vv \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.everest-preview+json" \
    "https://api.github.com/repos/ar90n/github-topics-trending/dispatches" \
    -d '{"event_type": "test_trigger", "client_payload": {}}'
