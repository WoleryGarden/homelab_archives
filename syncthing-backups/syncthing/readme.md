# Syncthing

An alternative to using the `docker-compose.yml` (below) is quick and dirty:

```bash
docker pull syncthing/syncthing
docker run --restart=unless-stopped --name syncthing -d -p 8384:8384 -p 22000:22000 -v "$(pwd)/sync:/var/syncthing"  syncthing/syncthing
```

After that in Actions -> Setting -> Gui, tick "Use HTTPS for GUI" and use https://server:8384 from now on.

For `docker-compose.yml` go to [syncthing](syncthing) and run `docker-compose up -d`. The ui will be at https://syncthing

In either case run `chown 1000:1000 -R ~/sync`

Go to syncthing web UI, Actions -> Setting -> Gui and set user and password.
