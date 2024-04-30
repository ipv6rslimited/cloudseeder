# Cloud Seeder by IPv6rs
### Easy One-click server appliances opening up self hosting to everyone.

[Cloud Seeder](https://ipv6.rs/cloudseeder/) by IPv6rs is a one-click server appliance wizard. It takes a highly opinionated approach to using container technology by deploying fat containers as isolated server appliances.

**Of course it's open source.**

![Cloud Seeder Preview](https://raw.githubusercontent.com/ipv6rslimited/cloudseeder/main/preview.png)

#### Preface

After conducting a survey, we discovered a much larger number of people wish to self-host than the current self-hosting base today.

Through a series of person-to-person interviews, we established two cohorts - the "too hard to setup" and "don't have IP addresses" groups.

[IPv6rs](https://ipv6.rs) is the answer to the latter, but the former left us curious.

#### Self-Hostathon

We proceeded to conduct a self-hostathon of sorts. Our participants ranged in expertise - with some having worked as computer repair specialists and others with web development experience.
There were also musicians and many other professional backgrounds not so directly related to the computer world. While all of the participants were able to setup their IPv6rs and DNS, few
were able to completely setup a self-hosted server (in this case, the options were Wordpress, Ghost or Mastodon).

We reviewed the actions taken by interviewing the partipants, individually, and found peculiar, yet understandable, errors abound; from typos to situations where the VM needed to be wiped.

#### The State of Server and Open Source Server Type Software Projects

It was surprising to us as we figured the install process was much simpler. When we look at the open source server softwares out there, they look amazing -- well polished, complete enterprise
worthy software applications used by the most popular websites in the world, and built, free and open source, by kind and beautiful contributors.

However, the multi-faceted, multi step and manual setup process proves to be a significant obstacle.

## Our Solution: Cloud Seeder by IPv6rs

Since we already solve the external IP issue with our [service](https://ipv6.rs), we decided to solve the setup issue. We'd like to introduce you to Cloud Seeder by IPv6rs which provides a simple graphical user interface to setup
appliances with just a click.

Cloud Seeder by IPv6rs was built using GoLang with its GUI powered by Fyne, which helps us to enable cross platform compatibility with a single, slim and descriptively readable, codebase.
Under the hood, it relies on the amazing [Podman](https://podman.io), which of course is open source.

Now, with one-click, you can have your software server appliance running from your own home computer in it's own encapsulated container.

The friction with self hosting is gone.

The decentralized era of self ownership is here.

Own your own data, and be happy. After all, **trust is not security**; everytime you trust an entity with your data, you increase your attack surface area by the size of that entity.

#### Current Supported Appliances

There will be many more appliances supported in the future. The current list is below:

- [Mastodon](https://github.com/mastodon/mastodon)

- [OpenWeb-UI](https://github.com/open-webui/open-webui) powered by [Ollama](https://ollama.com/)

- [Nextcloud](https://github.com/nextcloud)

- [code-server](https://github.com/coder/code-server)

- [Wordpress](https://github.com/WordPress/wordpress-develop)

- [Ghost](https://github.com/TryGhost/Ghost)

- [Misskey](https://misskey-hub.net/)

- [Lemmy](https://join-lemmy.org/)

- [Pixelfed](https://pixelfed.org/)

- [RocketChat](https://rocket.chat)

- [Vaultwarden](https://github.com/dani-garcia/vaultwarden)

- [Bluesky](https://github.com/bluesky-social/pds)

- Mail Server by [PostFix](https://postfix.org) and [Dovecot](https://dovecot.org)

- [Stalwart](https://stalw.art)

- [Jellyfin](https://jellyfin.org/)

- [PeerTube](https://joinpeertube.org/)

- [Immich](https://immich.app/)

- [Planka](https://planka.app/)

- [XMPP](https://xmpp.org/)

- [YaCy](https://yacy.net)

- [Gitea](https://gitea.com)

- [Gitlab](https://gitlab.com/gitlab-org/gitlab)

- [Minecraft](https://www.minecraft.net/en-us)

- [Funkwhale](https://funkwhale.audio)

- [Navidrome](https://www.navidrome.org)

- [LAMP Server](https://issues.apache.org/)

- Base [Ubuntu 22.04](https://ubuntu.com/)


#### Current Supported Architectures

Cloud Seeders by IPv6rs will instantly setup a server appliance for you on:

- MacOS (x86 or ARM)
- Windows 10, 11 (x86 only)
- Linux (gnome-terminal required) (x86 or ARM)

Podman must be installed first.


### How to Install

It's best to download the binaries from our Releases page. These follow the typical install scheme for each OS (installer for windows, dmg for MacOS and a folder for Linux)

If you'd like to compile yourself, you'll need Golang 1.21.0+ and then follow these instructions:

```
cd cloudseeder
cd src && go mod tidy
make
```

The unsigned binaries should be in a folder called cloudseeder/dist upon completion.

All of this has only been tested on MacOS but the build should work fine in Linux.

### Core Details

- simple, completely non-interactive installs 

- unattended security updates enabled by default for security

- using battle hardened and stable ubuntu 22.04 LTS for security and compatibility

- automated updates provided via tray menu

- sshd disabled by default for security

- syslog disabled by default for storage

- `CAP_NET_ADMIN`, `/dev/net/tun` `ro` access to `cgroups` are the only permissions required [1][2]

[1] SELinux is disabled.

[2] With the exception, as of writing, of bluesky which requires `privileged` access. Only run if you trust bluesky!

### Frequently Asked Questions (FAQ)

##### Why Open Source?

All of the appliances we support are open source, so of course we're open source too. Further, you need to know what you are installing and what that installed
software is doing for that matter -- our transparency in this process is our way of showing you our commitment to __you__.

##### Why did you use Go and not Electron?

We chose GoLang as the programming language to benefit from its cross-platform ability as well as small binary form factor versus, for example, nodeJS.

Additionally, we built a [Configurator](https://github.com/ipv6rslimited/configurator) which automatically generates a user-interface from a JSON file to run a script. We felt this would
be useful to other developers, so this has been separated as its own module which you can build and distribute with your own application subject to the open source license. This will
improve over time.

We also built [Tray](https://github.com/ipv6rslimited/tray) which generates a task tray from a JSON file. You can feel free to use it in your projects.

##### Why a fat container? Why not VM?

We initially built Cloud Seeder by IPv6rs as a VM launcher -- powered by Multipass. We made the pivot after researching extensive CVEs and other container escapes and cross
referenced against those relating to QEMU and virtualization/hypervisors, generally. It is not 2016 anymore. Containers have come a long way.

The biggest benefit is not needing to reserve RAM and CPU for each individual appliance allowing you to deploy several appliances versus a few.

We run the containers with NET_ADMIN and read-only access to cgroups. The assumption is that you're not running untrusted appliances, but if you are, they still need to escape the container in a meaningful way.

The exception is the appliances that run privileged for Cinch (Container IN Container Hierarchy).

##### How do I get the syslog?

Type `journalctl` or to get the end of the file, `journalctl -e` or tail with `journactl -f`

##### Can I install other stuff on my appliance?

You can, but we don't recommend it. When we release updates/upgrades these changes may conflict. Instead, launch another container or recommend an appliance to us if we don't have a package for it already!

##### When will more appliances come?

We are always working on more and they should arrive soon! :-)

##### How do we donate? This is great for decentralization and the self-hosting movement.

Please donate to the respective projects! These are awesome platforms built by great people who deserve these funds.

And when you're looking for an external IP, definitely give [IPv6rs](https://ipv6.rs) (us) a look.

### License

Copyright (c) 2024 [IPv6rs Limited <https://ipv6.rs>](https://ipv6.rs)

All Rights Reserved.

COOLER License.


