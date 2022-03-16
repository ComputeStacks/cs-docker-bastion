# Bastion host for ComputeStack Projects

This provides a bastion environment for projects running within ComputeStacks.

The will:

1) Install any ssh keys linked to the project and/or users.
2) Mount volumes for other services within the project
3) Provide ssh, sftp, and [mosh access](https://github.com/mobile-shell/mosh)
4) Provide developer tools such as: git, rsync, wp-cli, compose, yarn, npm, mysql-cli, postgres-cli.

_Note: This makes use of the metadata service provided by ComputeStacks. Not all features may work in your environment._

Based on source code and ideas from: [atmoz/sftp](https://github.com/atmoz/sftp)

[![gitlab ci](https://git.cmptstks.com/cs-public/images/bastion/badges/main/pipeline.svg)](https://git.cmptstks.com/cs-public/images/bastion/-/jobs)

## Submitting Issues

You may open an issue on our gitlab instance, [here](https://git.cmptstks.com/cs-public/images/bastion/-/issues). However, for questions or how-to's, please [post on our forum](https://forum.computestacks.com).


## Contributing

Contributions are welcome! Before you submit a pull request, feel free to [post on our forum](https://forum.computestacks.com) your idea and we can have a discussion.


