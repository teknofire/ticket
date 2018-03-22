# Ticket Command

This is a quick and dirty tool to handle some support ticket management tasks.  Specifically creating a set of directories for storing ticket files that are downloaded from Zendesk and interacting with those files.

This command is built using: https://github.com/basecamp/sub

## Install ticket command

Here's how to install the tool into your $HOME directory:

```
cd
git clone https://github.com/teknofire/ticket.git .ticket
```

For bash users:

```
echo 'eval "$($HOME/.ticket/bin/ticket init -)"' >> ~/.bash_profile
exec bash
```

For zsh users:

```
echo 'eval "$($HOME/.ticket/bin/ticket init -)"' >> ~/.zshrc
source ~/.zshrc
```

You can also install the command into a different directory, say `$HOME/projects/ticket` and adjust the paths to the `ticket init` command above as needed.

## Available commands

The tool should be mostly self documenting, to see all the available commands run: `ticket help`
