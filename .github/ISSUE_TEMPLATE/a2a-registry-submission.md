---
name: Registry submission for A2A AgentCard
about: File this issue when you want to add a new AgentCard to the registry
title: ''
labels: 'a2a'
assignees: ''

---

<!--
To add entries into this registry, you need to fill out the section enclosed by ~~~ below. 

Using this form requires that your Agent-to-Agent (A2A) Agentcard resides in a publicly accessible
Git repository and that the given path contains a valid agent.json manifest
that describes the agentcard.

When you submit the issue, the repository will be inspected, the agent.json
file will be sourced from the given location and copied into this registry.

The file will be registered at /agentcardproviders/{agentcardprovider}/agentcards/{agentcard}.

If the agentcardprovider name and agentcard name are already taken, the request will be rejected.

- repo: Path to the repo (e.g. org/repo) on Github or an absolute URL to a Git repo elsewhere
- path: Path (folder) in the repo where the `agent.json` file can be found
- branch: Branch of the repo to look up
- agentcardprovider: The name of the agentcardprovider group to put the registration into. 
                     You or your company are the provider.
- agentcard: Identifier of the agentcard to register. 

The agentcardprovider and agentcard values must conform to this rule:

MUST be a non-empty string consisting of RFC3986 unreserved characters (ALPHA / DIGIT / - / . / _ / ~) and @, MUST start with ALPHA, DIGIT or _ and MUST be between 1 and 128 characters in length.

!-->

~~~
repo: <repo>
path: <path>
branch: <branch>
agentcardprovider: <the agentcardprovider group in the registry>
agentcard: <the agentcard name in the registry>
~~~

