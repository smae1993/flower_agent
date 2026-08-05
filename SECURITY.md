# Security Policy

## Supported versions

Flower Agent is currently in pre-release development. Security fixes are applied to the latest development release and the `main` branch.

## Reporting a vulnerability

Please do not disclose a vulnerability through a public GitHub issue when it could expose user source code, overwrite local files, execute unintended commands, or leak secrets.

Send a private report to the repository owner through GitHub's private vulnerability reporting feature when it is enabled. Include:

- the affected command and version;
- operating system and Dart version;
- a minimal reproduction;
- the potential impact;
- any suggested mitigation.

## Security priorities

Flower Agent treats the following as security-sensitive behavior:

- reading files outside the selected project root;
- following unsafe symbolic links;
- overwriting user-authored configuration;
- including secrets in generated context or reports;
- executing project scripts without explicit consent;
- transmitting source code or metadata over the network;
- accepting untrusted rule or plugin code.

Flower's default operation is local-only. Networked integrations must be explicit, documented, and disabled by default.
