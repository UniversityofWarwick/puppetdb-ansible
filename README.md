# PuppetDB dynamic inventory for Ansible

This script provides a dynamic inventory for Ansible to get information about hosts from PuppetDB.

This is in semi-prototype stages and has a number of caveats, especially if you want to use it
outside of the specific environment I've written it for:

* It attempts to group hosts based on specific parameters from a specific Nodes::Exported_metadata
  resource. I plan to pull this bit out into a subclass, so that the base class can be extended with
  any site-specific grouping rules.
* It also restricts hosts to a particular deployment (staging, production etc) based on a
  NODE_DEPLOYMENT environment variable, and will quit if that's not present. See above.
* No caching, so each run goes to PuppetDB. It's fairly efficient though - even listing all hosts only
  requires 3 calls (which could be reduced to 2). This is an improvement over a similar module available
  on GitHub which makes 2N+2 calls for N hosts.

## Setup

Copy `settings.yml.sample` to `settings.yml` and edit to taste. You can leave out the SSL settings if
you are using an HTTP endpoint. These settings are passed straight through to the `puppetdb` gem that
does all the hard work of talking to PuppetDB.
