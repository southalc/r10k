#### r10k control repository

1. [Intro](#Intro)
1. [Setup](#Setup)
1. [Repository](#Repository)
1. [Deployment](#Deployment)

## Intro
The [r10k](https://github.com/puppetlabs/r10k) utility is used to deploy dynamic Puppet environments from version control repositories like `git`.  This enables configuration
management of both Puppet modules and hiera data.  This setup for r10k will deploy a separate Puppet environment for each branch in your source git repository, creating a
flexible and automated way to deploy new environments for testing and merge tested changes into production environments using typical git workflows.

This control repository includes a hiera hierachy and example data files to perform all node configuration by leveraging the [types module](https://forge.puppet.com/southalc/types)
to avoid writing any Puppet code.  This design provides a standard configuration based on operating system version with the ability to override data as needed for specific nodes
or deployment platforms.  Applications can be assigned using the `role` variable either through site manifests or through an [ENC](https://github.com/southalc/enc).

Defining roles this way is counter to the common [roles/profiles](https://puppet.com/docs/pe/latest/roles_and_profiles_example.html) method.  A purported advantage of the
roles/profiles design is the ability to assign multiple profiles to compose a more complex server role.  This may have made sense years ago, but I've found that the typical server
today is virtualized and dedicated to running a single application.  The approach of applying a standard OS baseline with a single application role all defined in hiera YAML files
has proven to be effective and enables the entire configuration to be easily managed from simple YAML files.

## Setup
First, create a new git repository to serve as your control repository for Puppet.  This can be on any git server either on-prem or cloud hosted.  Clone this git repository to a
local working directory, remove the origin, add your new repository as the origin, and push to the new origin using 'production' as the branch name.
```
git clone https://github.com/southalc/r10k.git
git remote remove origin 
git remote add origin <URL_TO_YOUR_NEW_GIT_REPO>
git push -u origin production

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
The `postrun` script copies a `site.yaml` file from the r10k directory to each deployed environment.  This allows us to separate out site-specific, security sensitive data like
password hashes, network configuration, and Active Directory keytabs and prevent them from being pushed to public git servers.  Copy the included `site.yaml` file from this
repository to your r10k directory and update the values for your deployment, using the descriptions provided in the `site.yaml` example file.

Set proper permissions and ownership on the r10k configuration file, postrun script, and site.yaml:
```
chown root:puppet /etc/puppetlabs/r10k/r10k.yaml /etc/puppetlabs/r10k/postrun.sh /etc/puppetlabs/r10k/site.yaml
chmod 640 /etc/puppetlabs/r10k/site.yaml
chmod 644 /etc/puppetlabs/r10k/r10k.yaml
chmod 750 /etc/puppetlabs/r10k/postrun.sh
```
Ensure the user that will run r10k (usually root) has access to your git repository.  This is usually done by generating a new SSH key pair and associating the public key to your
git repository as a deployment key.  This example configuration snippet for the root user's SSH file `/root/.ssh/config` defines how the SSH connection to the git server will
authenticate using the SSH private key stored in `/etc/puppetlabs/r10k/.ssh/r10k_key`.  Ensure SSH keys are protected with appropriate file permissions.
```
Host <GIT_SERVER_FQDN>
  IdentityFile /etc/puppetlabs/r10k/.ssh/r10k_key
  IdentitiesOnly yes
```

## Repository
Per the `environment.conf` file, this reference repository uses Puppet manifests ('.pp' files) located in the `manifests` subdirectory.  The current `site.pp` manifest performs a
hiera lookup for classes to be included with the node definition.  Rules may be defined in the manifest files as needed to assign a role as a variable before the hiera lookup for
classes is performed, enabling the role assignment to be referenced in the hiera hierarchy.  While this method works, using my [ENC](https://github.com/southalc/enc) offers
several advantages and is recommended.

Hiera provides a back-end data service for Puppet.  The `hiera.yaml` file defines the order in which Puppet will search data files.  Data files are stored in the `data`
subdirectory as common YAML files.  Variables can be referenced in the hiera configuration indicated by the percent sign and curly braces.  Variables are either facts as provided
by the node, or variables assigned by either the [main manifest](https://puppet.com/docs/puppet/latest/dirs_manifest.html) or an [ENC](https://github.com/southalc/enc).

You'll notice that this Puppet environment contains no modules.  This is because modules are managed by r10k through definitions in the [Puppetfile](https://puppet.com/docs/pe/latest/puppetfile.html).
Modules in the Puppetfile typically come from Puppet Forge, but can also come directly from git repositories.  The Puppetfile here contains all the modules needed to apply the
resources defined in the included hiera data files.  Modify your repository as needed, commit/push to git, and deploy with r10k.

## Deployment
Once `r10k` is installed and configured on the Puppet master and environments established from branches in your git repository, changes to Puppet code and hiera data should be
exclusively managed through git and r10k.  New branches created in git will result in new environments deployed on the Puppet master.  This supports testing of changes on new
branches, and when tests are completed the test branch can be merged to the target environment.  It's possible to enable a webhook on the git repository to trigger an automatic
code deployment to Puppet, but it requires an external tool like [Jenkins](https://www.jenkins.io/) to serve as the webhook endpoint.  To manually deploy from your git repo to
the Puppet server, run:
```
/opt/puppetlabs/puppet/bin/r10k deploy environment -pv --generate-types
```

