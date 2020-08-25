#### r10k control repository

1. [Intro](#Intro)
1. [Setup](#Setup)
1. [Repository](#Repository)
1. [Deployment](#Deployment)

## Intro
The [r10k](https://github.com/puppetlabs/r10k/blob/master/doc/dynamic-environments/configuration.mkd) utility is used to deploy dynamic Puppet environments from version control
repositories like `git`.  This enables configuration management of both Puppet modules and hiera data.  By default, r10k will deploy a separate Puppet environment for each branch
in the source git repository.  This enables a flexible way to create new environments for testing and merge tested changes into production environments using typical git workflows.

This control repository includes a hiera hierachy and example data files to perform all node configuration by leveraging the [types module](https://forge.puppet.com/southalc/types)
to avoid writing any actual Puppet code.  This design provides a standard configuration based on operating system version, with the ability to override data as needed for specific
nodes or deployment platforms.  Applications are deployed by assigning the `role` variable either through site manifests or through an [ENC](https://puppet.com/docs/puppet/latest/nodes_external.html).

Defining roles this way is counter to the common [roles/profiles](https://puppet.com/docs/pe/2019.8/roles_and_profiles_example.html) module.  A purported advantage of the
roles/profiles design is the ability to assign multiple profiles to a more complex server role.  This may have made sense years ago, but the typical server today is virtualized
and dedicated to running a single application.  I've found it to be very effective to construct a standard operating system configuration coupled with an application role all
defined entirely in hiera data without resorting to writing any actual Puppet code.

## Setup
First, create a new git repository to serve as your control repository for Puppet.  This can be on any git server either on-prem or cloud hosted.  Clone this git repository to a
local working directory, remove the origin, add your new repository as the origin, and push to the new origin using 'production' as the branch name.
```
git clone https://github.com/southalc/r10k.git
git remote remove origin 
git remote add origin <URL_TO_YOUR_NEW_GIT_REPO>
git push origin production

```
Once you have your own control repository established, configure your Puppet server to use it with r10k.  Install 'r10k' on the Puppet master using Ruby Gems from the runtime
embedded with Puppet.  Using the embedded Ruby runtime from Puppet ensures that any distribution-managed Ruby runtime will remain unchanged.
```
/opt/puppetlabs/puppet/bin/gem install r10k
```
Still on the Puppet master, configure r10k by updating `/etc/puppetlabs/r10k/r10k.yaml` as needed to use your git repository.
```
cachedir: '/var/cache/r10k'

sources:
  production:
    remote: '<URL_TO_YOUR_NEW_GIT_REPO>'
    basedir: '/etc/puppetlabs/code/environments'
    prefix: false
    purge_whitelist:
      - '.resource_types'

# Copy 'site.yaml' sensitive hiera data file to environment(s)
postrun: ['/etc/puppetlabs/r10k/postrun.sh']
```
Create the 'postrun' script referenced in `r10k.yaml` that's  used to copy site sensitive data that is excluded from git into each deployed environment:
```
#!/bin/bash
# Deploy site-specific data file to all environments

SITE_YAML='/etc/puppetlabs/r10k/site.yaml'
ENVIRONMENTS='/etc/puppetlabs/code/environments'

for ENVIRONMENT in $(ls ${ENVIRONMENTS})
  do
  # Copy site data to the environment
  HIERADATA="${ENVIRONMENTS}/${ENVIRONMENT}/data"
  [[ -d ${HIERADATA} ]] && cp -p "${SITE_YAML}" "${HIERADATA}"
done
```
Set proper permissions and ownership on the r10k configuration file and postrun script:
```
chown root:puppet /etc/puppetlabs/r10k/r10k.yaml /etc/puppetlabs/r10k/postrun.sh
chmod 644 /etc/puppetlabs/r10k/r10k.yaml
chmod 750 /etc/puppetlabs/r10k/postrun.sh
```
Ensure the user that will run r10k (usually root) has access to the repository.  This is usually done by generating a new SSH key pair and associating the public key to your git
repository as a deployment key.  This example configuration snippet for the root user's SSH file `/root/.ssh/config` defines how the SSH connection to the git server will
authenticate using the SSH private key stored in `/etc/puppetlabs/r10k/.ssh/r10k_key`:
```
Host <GIT_SERVER_FQDN>
  IdentityFile /etc/puppetlabs/r10k/.ssh/r10k_key
  IdentitiesOnly yes
```

## Repository
Per the `environment.conf` file, this reference repository uses Puppet manifests ('.pp' files) located in the `manifests` subdirectory.  The current `site.pp` manifest performs a
hiera lookup for classes to be included with the node definition.  Rules may be defined in the manifest files as needed to assign a role as a variable before the hiera lookup for
classes is performed, enabling the role to be used within the hiera hierarchy.

Hiera provides a back-end data service for Puppet.  The `hiera.yaml` file defines the order in which Puppet will search data files.  Data files are stored in the `data`
subdirectory as common YAML files.  Variables can be referenced in the hiera configuration indicated by the percent sign and curly braces.  Variables are either facts as provided
by the node, or variables assigned by either the [main manifest](https://puppet.com/docs/puppet/latest/dirs_manifest.html) or an [External Node Classifier](https://puppet.com/docs/puppet/latest/nodes_external.html).

Modules are added to environments through the [Puppetfile](https://puppet.com/docs/pe/latest/puppetfile.html).  Modules in the Puppetfile typically come from Puppet Forge, but
can also come directly from git repositories.  This control repository incudes a Puppetfile with all the modules needed to apply the resources defined in the hiera data files.
Add modules to the Puppetfile in your repository as needed.

## Deployment
Once `r10k` is installed and configured on the Puppet master and environments have been added to a configured git repository, changes to Puppet code and hiera data should be
managed through git.  Make changes as needed, commit to git, then deploy with r10k.  New branches created in git will result in new environments deployed on the Puppet master.
This supports testing of changes on new branches, and when tests are completed the test branch can be merged to the target environment.
```
/opt/puppetlabs/puppet/bin/r10k deploy environment -pv --generate-types
```
