# Ticket Command

This is a quick and dirty tool to handle some support ticket management tasks.  Specifically creating a set of directories for storing ticket files that are downloaded from Zendesk and interacting with those files.

This command is built using: https://github.com/basecamp/sub

## Requirements

* ruby 2+
* jq (for the `ticket profile` command)

## Install ticket command

Here's how to install the tool into your $HOME directory:

```
cd
git clone https://github.com/teknofire/ticket.git .ticket
cd .ticket
bundle
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

## Configuration

To access the zendesk API you will need to create a config file with the API credentials.  Follow the instructions below on how to do that.

#### Creating config file

To use the `ticket download` command you will need to create a config file in `~/.support/ticket.toml`

Download the example [ticket.toml](ticket-example.toml) config and update it with the correct API values. The token is available in LastPass. Sendsafely tokens can be obtained directly from Sensdafely.

##### Supported config options

It's also possible to control by setting an environment variable. I've noted below where those apply

* __ticket_path__ (default: `~/support`, ENV: `TICKET_ROOT`): Location to store local ticket information.  
* __autodownload__ (default: `false`): Automatically download ticket attachments when opening a ticket
* __open_browser__ (default: `false`, ENV: `TICKET_OPEN_BROWSER`): Open a browser when opening a ticket
* __zendesk_url__: URL for customer Zendesk API
* __zendesk_user__: Email address of Zendesk User
* __zendesk_token__: Token for API access for Zendesk User
* __sendsafely_url__: (default: "https://secure.chef.io/") URL for Sendsafely Dropzone
* __sendsafely_key_id__: Sendsafely API Key Id, Obtain from API Keys section under https://secure.chef.io/secure/profile/
* __sendsafely_key_secret__: Sendsafely API Key Secret, Obtain from API Keys section under https://secure.chef.io/secure/profile/

## Available commands

The tool should be mostly self documenting, to see all the available commands run: `ticket help`

Then to see more specific help about a command run: `ticket help SUBCOMMAND`

### ticket profile

This command is used to create some graphs from various log files normally captured by `gather-logs` in various chef-products.  If you specify the `-j` or `--jq-value` option this will require that you have the `jq` command installed on your local system.  

This was originally part of the `chef/support-docs` tools.  

To see the type of logs files that this command supports run `ticket profile --help` and look at the `-t` available options.

Examples:

```
# from the gather-logs folder
$ ticket profile -t expander -s var/log/opscode/opscode-expander/current
2018-07-25 14:18:18     40 r/s [#####################################################                           ]
2018-07-25 14:18:19     53 r/s [######################################################################          ]
2018-07-25 14:18:20     25 r/s [#################################                                               ]
2018-07-25 14:18:21     40 r/s [#####################################################                           ]
2018-07-25 14:18:22     44 r/s [##########################################################                      ]
2018-07-25 14:18:23     33 r/s [############################################                                    ]
2018-07-25 14:18:24     45 r/s [############################################################                    ]
2018-07-25 14:18:25     47 r/s [##############################################################                  ]
2018-07-25 14:18:26     41 r/s [######################################################                          ]
2018-07-25 14:18:27     34 r/s [#############################################                                   ]
2018-07-25 14:18:28     37 r/s [#################################################                               ]
2018-07-25 14:18:29     56 r/s [##########################################################################      ]
2018-07-25 14:18:30     17 r/s [######################                                                          ]
--------------------------------------------------------------------------------
Min value: 4
Max value: 60
Standard Deviation: 8.158455006290227
90th percentile: 50
--------------------------------------------------------------------------------
```

* this next command shows a very useful filter to use when looking for CCRs specifically, as it filters for PUT/POST to the node endpoint
  it's run from the `~/support/$orgname/$ticketnumber/` directory in this example

```
23899 ticket profile -t nginx2 -h -M -d -f '(PUT|POST) /organizations/[^\/]+/node' ./ip-10-13-96-54.us-west-2.compute.internal/2019-11-28_02.25.50-UTC/var/log/opscode/nginx/access.log
```

## Updates

Once the `ticket` command is available on your system you can update it by running `ticket update`.  This will pull down the latest changes from GitHub and runs the `bundle`.

## Troubleshooting

* Errors with missing gems when switching between different versions of ruby.
  * To install the latest gem dependencies for a new ruby version run the `ticket shave` commmand, or possibly update the tool using `ticket update`. This should install the latest gems in the active ruby environment.
