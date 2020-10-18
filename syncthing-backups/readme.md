# Example of setting up syncthing server

Review and change configs:

* [syncthing/docker-compose.yml](traefik/docker-compose.yml) - update `domain.tld` to actual domain
* [traefik/docker-compose.yml](traefik/docker-compose.yml) - make sure that `CF_DNS_API_TOKEN` is defined either in `.env` file on in an environment variable before running `docker-compose`
* [traefik/traefik.toml](traefik/traefik.toml) - update `email@domain.tld`

See [traefik-example](https://github.com/WoleryGarden/homelab_archives/tree/main/traefik-example) on general structure of this folder.
