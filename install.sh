#!/bin/bash
set -e

USERNAME=gitpod
HOMEDIR=/home/gitpod
IDNUM=33333

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

deprecation_notice() {
	distro=$1
	distro_version=$2
	echo
	printf "\033[91;1mDEPRECATION WARNING\033[0m\n"
	printf "    This Linux distribution (\033[1m%s %s\033[0m) reached end-of-life and is no longer supported by this script.\n" "$distro" "$distro_version"
	echo   "    No updates or security fixes will be released for this distribution, and users are recommended"
	echo   "    to upgrade to a currently maintained version of $distro."
	echo
	sleep 10
}

get_distribution() {
	lsb_dist=""
	# Every system that we officially support has /etc/os-release
	if [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi
	# Returning an empty string here should be alright since the
	# case statements don't act unless you provide an actual value
	echo "$lsb_dist"
}

do_install() {

	# perform some very rudimentary platform detection
	lsb_dist=$( get_distribution )
	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

	case "$lsb_dist" in

		ubuntu)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --codename | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
				dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
			fi
		;;

		debian|raspbian)
			dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
			case "$dist_version" in
				11)
					dist_version="bullseye"
				;;
				10)
					dist_version="buster"
				;;
				9)
					dist_version="stretch"
				;;
				8)
					dist_version="jessie"
				;;
			esac
		;;

		centos|rhel|sles)
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			fi
		;;

		*)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --release | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			fi
		;;

	esac

	# Print deprecation warnings for distro versions that recently reached EOL,
	# but may still be commonly used (especially LTS versions).
	case "$lsb_dist.$dist_version" in
		debian.stretch|debian.jessie)
			deprecation_notice "$lsb_dist" "$dist_version"
			;;
		raspbian.stretch|raspbian.jessie)
			deprecation_notice "$lsb_dist" "$dist_version"
			;;
		ubuntu.xenial|ubuntu.trusty)
			deprecation_notice "$lsb_dist" "$dist_version"
			;;
		fedora.*)
			if [ "$dist_version" -lt 33 ]; then
				deprecation_notice "$lsb_dist" "$dist_version"
			fi
			;;
	esac

	# Run setup for each distro accordingly
	case "$lsb_dist" in
		ubuntu|debian)
            echo "Installing ubuntu/debian"

            debconf-set-selections <<<'debconf debconf/frontend select Noninteractive'

            apt-get update 
            apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl bash-completion \
                                less locales man-db sudo time lsof 

            debconf-set-selections <<<'debconf debconf/frontend select Readline'

            locale-gen en_US.UTF-8

            useradd -l -u ${IDNUM} -G sudo -md ${HOMEDIR} -s /bin/bash -p ${USERNAME} ${USERNAME}
            echo >> "%sudo        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers

            curl -fsSL https://get.docker.com | bash

            curl -o /usr/bin/slirp4netns -fsSL https://github.com/rootless-containers/slirp4netns/releases/download/v1.1.12/slirp4netns-$(uname -m) \
                && chmod +x /usr/bin/slirp4netns

            curl -o /usr/local/bin/docker-compose -fsSL https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-linux-$(uname -m) \
                && chmod +x /usr/local/bin/docker-compose && mkdir -p /usr/local/lib/docker/cli-plugins && \
                ln -s /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose
            
            apt-get clean -y

            rm -rf \
                /var/cache/debconf/* \
                /var/lib/apt/lists/* \
                /tmp/* \
                /var/tmp/*

            exit 0
		    ;;
		centos|fedora)
            echo "Installing CentOS/Fedora"

            yum install -y ca-certificates curl less  man-db sudo time lsof
            groupadd sudo
            useradd -l -u ${IDNUM} -G sudo -md ${HOMEDIR} -s /bin/bash -p ${USERNAME} ${USERNAME}
            echo "%sudo        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers

            curl -fsSL https://get.docker.com | sh
            
            curl -o /usr/bin/slirp4netns -fsSL https://github.com/rootless-containers/slirp4netns/releases/download/v1.1.12/slirp4netns-$(uname -m) \
                && chmod +x /usr/bin/slirp4netns

            curl -o /usr/local/bin/docker-compose -fsSL https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-linux-$(uname -m) \
                && chmod +x /usr/local/bin/docker-compose && mkdir -p /usr/local/lib/docker/cli-plugins && \
                ln -s /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

            exit 0
            ;;
        rhel)
            echo "RHEL is not currently supported. Patches welcome."
            exit 1
            ;;
		sles)
			echo "SLES is not currently supported. Patches welcome."
			exit 1
			;;
        almalinux)
			echo "Alma Linux is not currently supported. Patches welcome."
			exit 1
			;;
        fedora)
			echo "Fedora is not currently supported. Patches welcome."
			exit 1
			;;
		*)
			echo
			echo "ERROR: Unsupported distribution '$lsb_dist'"
			echo
			exit 1
			;;
	esac
	exit 1
}

do_install