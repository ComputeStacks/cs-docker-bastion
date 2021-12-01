# Bastion host for ComputeStack Projects

This provides a bastion environment for projects running within ComputeStacks.

The will:

1) Install any ssh keys linked to the project and/or users.
2) Mount volumes for other services within the project
3) Provide ssh, sftp, and [mosh access](https://github.com/mobile-shell/mosh)
4) Provide developer tools such as: git, rsync, wp-cli, compose, yarn, npm, mysql-cli, postgres-cli.

_Note: This makes use of the metadata service provided by ComputeStacks. Not all features may work in your environment._

Based on source code and ideas from: [atmoz/sftp](https://github.com/atmoz/sftp)
