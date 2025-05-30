# Chronograf
 
## References

- [*influxdata Chronograf* documentation](https://docs.influxdata.com/chronograf/)
- [*GitHub*: influxdata/influxdata-docker/chronograf](https://github.com/influxdata/influxdata-docker/tree/master/chronograf)
- [*DockerHub*: influxdata Chronograf](https://hub.docker.com/_/chronograf)

## Kapacitor integration

If you selected Kapacitor in the menu and want Chronograf to be able to interact with it, you need to edit `docker-compose.yml` to un-comment the lines which are commented-out in the following:

```yaml
chronograf:
  …
  environment:
  …
  # - KAPACITOR_URL=http://kapacitor:9092
  depends_on:
  …
  # - kapacitor
```

If the Chronograf container is already running when you make this change, run:

``` console
$ cd ~IOTstack
$ docker-compose up -d chronograf
```

## Upgrading Chronograf

You can update the container via:

``` console
$ cd ~/IOTstack
$ docker-compose pull
$ docker-compose up -d
$ docker system prune
```

In words:

* `docker-compose pull` downloads any newer images;
* `docker-compose up -d` causes any newly-downloaded images to be instantiated as containers (replacing the old containers); and
* the `prune` gets rid of the outdated images.

See also [2025-03-04 patch](#patch1).

### Chronograf version pinning

If you need to pin to a particular version:

1. Use your favourite text editor to open `docker-compose.yml`.
2. Find the line:

	``` yaml
	image: chronograf:latest
	```

3. Replace `latest` with the version you wish to pin to. For example, to pin to version 1.9.0:

	``` yaml
	image: chronograf:1.9.0
	```

4. Save the file and tell `docker-compose` to bring up the container:

	``` console
	$ cd ~/IOTstack
	$ docker-compose up -d chronograf
	$ docker system prune
	```

<a name="patch1"></a>
## 2025-03-04 patch

Chronograf does not start properly from a clean slate. The cause is explained [here](https://github.com/influxdata/influxdata-docker/pull/781).

You can solve the problem in two ways:

1. You can set the correct permissions yourself:

	``` console
	$ cd ~/IOTstack
	$ docker-compose down chronograf
	$ sudo chown -R 999:999 ./volumes/chronograf
	$ docker-compose up -d chronograf
	```
	
	Generally, this is a one-time fix. You will only need to repeat it if you start Chronograf from a clean slate.
	
2. You can adopt the updated service definition, either by:

 	- using the menu to delete then reinstall `chronograf`; or by
 	- using a text editor to hand-merge the contents of:

		```
		~/IOTstack/.templates/chronograf/service.yml
		```
		
		with:
		
		```
		~/IOTstack/docker-compose.yml
		```

If you adopt the updated service definition then the process for keeping Chronograf up-to-date becomes:

``` console
$ cd ~/IOTstack
$ docker-compose build --no-cache --pull chronograf
$ docker-compose up -d chronograf
$ docker system prune
```
