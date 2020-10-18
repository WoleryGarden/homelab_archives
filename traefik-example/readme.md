# Sample traefik setup

This is a sample docker based setup of traefik for TLS termination and Let's Encrypt cert renewal that I run on my VMs.

Let's Encript is used in TLS challange mode, which means that you need to set up LE reachable DNS to point to traefik installation prior to running this. Traefik Dashboard dns (if used) and each app DNS should be setup to point to the installation this way.

Run `docker network create http_network` to create a network for traefik to communicate with the apps that are going to be exposed with traefik.
Apps can reside on more than one network, but in this set up `http_network` is the one that both `traefik` and each of your exposed apps should be on.

I chose to have separate docker-compose for traefik and for each of the apps:

* [traefik](traefik) - traefik setup
* [sample-app](sample-app) - sample-app setup, repeat for each app

Review and change configs:

* [traefik/docker-compose.yml](traefik/docker-compose.yml) - setup traefik dashboard and autentication for it
* [traefik/file.toml](traefik/file.toml) - ususally does not need changes, default TLS setup
* [traefik/traefik.toml](traefik/traefik.toml) - configure LE email, LE server, logging and dashboard (also if want to use DNS challenge instead of TLS)
* [sample-app/docker-compose.yml](sample-app/docker-compose.yml) - for each app, configure each app

To run execute: `docker-compose up -d --force-recreate` in each subdirectory.

To install docker and compose on Ubuntu, I ususally run:

```bash
sudo apt-get install -o Dpkg::Options::="--force-confold" -y apt-transport-https ca-certificates curl git
DOCKER_COMPOSE_VERSION=`git ls-remote https://github.com/docker/compose | grep refs/tags | grep -oE "[0-9]+\.[0-9][0-9]+\.[0-9]+$" | sort --version-sort | tail -n 1`
curl -fsSL get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt-get install jq -y
sudo curl -L https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```
