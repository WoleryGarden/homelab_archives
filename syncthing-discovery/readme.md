# Example of setting up syncthing discover server

When running a host of VM with syncthing behind the same public IP discovery does not work very well, especially if the VMs are on different subnets. This is an example of setting up a discovery server to help with this issue. Note that the discovery server will not work on the same box as syncthing itself, it has to be installed on a separate VM.

Review and change configs:

* [syncdisc/docker-compose.yml](traefik/docker-compose.yml) - update `domain.tld` to actual domain
* [traefik/docker-compose.yml](traefik/docker-compose.yml) - make sure that `CF_DNS_API_TOKEN` is defined either in `.env` file on in an environment variable before running `docker-compose`
* [traefik/traefik.toml](traefik/traefik.toml) - update `email@domain.tld`

See [traefik-example](https://github.com/WoleryGarden/homelab_archives/tree/main/traefik-example) on general structure of this folder.
