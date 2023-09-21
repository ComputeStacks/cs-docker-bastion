# Changelog for ComputeStacks Bastion Container

## v3.0.0

Upgraded base OS to Debian Bookworm

* PHP 7.4 -> 8.2
* Cleaned up package install to reduce size.
* Now expects to be run with `docker run --init`.

***

## v2.2.0

* Extendify installation script (for hosting providers with license key) available at `install_extendify`. Non-hoster users can use the normal WordPress plugin installation process.
* Modify OCP installer. 

***

## v2.1.0

* Include php redis and relay versions that match our wordpress installations.
* Include script to install Object Cache Pro. Can be invoked with `install_ocp -h`.
* Added `redis-cli`.
* Update nodejs from 16 to 18.