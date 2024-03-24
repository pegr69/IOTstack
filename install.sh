#!/bin/bash

echo "                                         "
echo "  _____ ____ _______  _             _    "
echo " |_   _/ __ \\__   __|| | installer | |   "
echo "   | || |  | | | |___| |_ __ _  ___| | __"
echo "   | || |  | | | / __| __/ _\` |/ __| |/ /"
echo "  _| || |__| | | \\__ \\ || (_| | (__|   < "
echo " |_____\\____/  |_|___/\\__\\__,_|\\___|_|\\_\\"
echo "                                         "
echo "                                         "

#----------------------------------------------------------------------
# The intention of this script is that it should be able to be run
# multiple times WITHOUT doing any harm. If you propose changes, please
# make sure you test the script in both a "green fields" system AND on
# a working system where docker, docker-compose and IOTstack are already
# installed.
#----------------------------------------------------------------------

# overuse of sudo is a very common problem among new IOTstack users
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit 1

# the name of this script is
SCRIPT=$(basename "$0")

# this script should be run without arguments
[ $# -ne 0 ] && echo "$SCRIPT parameter(s) $@ ignored"

# assumption(s) which can be overridden
IOTSTACK=${IOTSTACK:-"$HOME/IOTstack"}

# form absolute path
IOTSTACK=$(realpath "$IOTSTACK")

# derived path(s) - note that the menu knows about most of these so
# they can't just be changed without a lot of care.
IOTSTACK_ENV="$IOTSTACK/.env"
IOTSTACK_MENU_REQUIREMENTS="$IOTSTACK/requirements-menu.txt"
IOTSTACK_MENU_VENV_DIR="$IOTSTACK/.virtualenv-menu"
IOTSTACK_INSTALLER_HINT="$IOTSTACK/.new_install"

# git cloning options which can be overridden
# (needs special handling for the null case)
if [[ ! -v GIT_CLONE_OPTIONS ]] ; then
	GIT_CLONE_OPTIONS="--filter=tree:0"
fi

# the expected installation location of docker-compose-plugin is
COMPOSE_PLUGIN_PATH="/usr/libexec/docker/cli-plugins/docker-compose"

# the default location of a symlink in the PATH pointing to the above is
COMPOSE_SYMLINK_PATH="/usr/local/bin/docker-compose"

# add these to /boot/cmdline.txt (if it exists)
CMDLINE_OPTIONS="cgroup_memory=1 cgroup_enable=memory"

# dependencies installed via apt
APT_DEPENDENCIES="curl git jq python3-pip python3-dev python3-virtualenv uuid-runtime whiptail"

# minimum version requirements
DOCKER_VERSION_MINIMUM="24"
COMPOSE_VERSION_MINIMUM="2.20"
PYTHON_VERSION_MINIMUM="3.9"

# best-practice for group membership
DESIRED_GROUPS="docker bluetooth"

# what to do at script completion (reboot takes precedence)
REBOOT_REQUIRED=false
LOGOUT_REQUIRED=false

#----------------------------------------------------------------------
#						Check script dependencies
#----------------------------------------------------------------------

echo -e -n "\nChecking operating-system environment - "
# This script assumes apt and dpkg are available. That's more-or-less
# the same as saying Debian oe Debian-derived. If apt and/or dpkg are
# missing then there's not much that can be done.
if [ -z $(which apt) -o -z $(which dpkg) ] ; then
	echo "fail"
	unset ID
	[ -f "/etc/os-release" ] && eval $(grep "^ID=" /etc/os-release)
	if [ "$ID" = "debian" ] ; then
		echo "This system looks like it is based on Debian but seems to be missing"
		echo "some key utilities (apt and/or dpkg). That suggests something is wrong."
		echo "This script can't proceed until those issues are resolved."
	else
		echo "Some key utilities that are needed by this script seem to be missing"
		echo "from this system. Both the Advanced Package Tool (apt) and the Debian"
		echo "Package Manager (dpkg) are core components of Debian and Debian-derived"
		echo "distributions like Raspberry Pi OS (aka Raspbian). It looks like you"
		echo "might be trying to install IOTstack on a system which isn't based on"
		echo "Debian. IOTstack has only ever been tested on Debian-based distributions"
		echo "and is not qualified for other Linux or Unix distributions. This script"
		echo "can't proceed."
	fi
<<<<<<< HEAD

	if [ "${CURR_VERSION_MAJOR}" -ge $REQ_MIN_VERSION_MAJOR ] && \
		[ "${CURR_VERSION_MINOR}" -ge $REQ_MIN_VERSION_MINOR ]; then
		VERSION_GOOD="true"
		echo "$VERSION_GOOD"
		return 0
	else
		VERSION_GOOD="false"
	fi

	if [ "${CURR_VERSION_MAJOR}" -ge $REQ_MIN_VERSION_MAJOR ] && \
		[ "${CURR_VERSION_MINOR}" -ge $REQ_MIN_VERSION_MINOR ] && \
		[ "${CURR_VERSION_BUILD}" -ge $REQ_MIN_VERSION_BUILD ]; then
		VERSION_GOOD="true"
		echo "$VERSION_GOOD"
		return 0
	else
		VERSION_GOOD="false"
	fi

	echo "$VERSION_GOOD"
}

function user_in_group()
{
	if grep -q $1 /etc/group ; then
		if id -nGz "$USER" | grep -qzxF "$1";	then
				echo "true"
		else
				echo "false"
		fi
	else
		echo "notgroup"
	fi
}

function install_python3_and_deps() {
	CURR_PYTHON_VER="${1:-Unknown}"
	CURR_VIRTUALENV="${2:-Unknown}"
  if ([ "$NOASKCONFIRM" == "true" ] ||
      whiptail --title "Python 3 and virtualenv" --yesno "Python 3.6.9 or later (Current = $CURR_PYTHON_VER) and virtualenv (Installed = $CURR_VIRTUALENV) are required for the main menu. Install these now?" 20 78); then
    echo "Installing Python3 and virtualenv"
    sudo apt install -y python3-dev python3-virtualenv
    if [ $? -eq 0 ]; then
      PYTHON_VERSION_GOOD="true"
    else
      echo "Failed to install Python and virtualenv" >&2
      exit 1
    fi
  fi
}

function install_docker() {
  if command_exists docker; then
    echo "Docker already installed" >&2
  else
    echo "Install Docker" >&2
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
  fi

  if command_exists docker-compose; then
    echo "docker-compose already installed" >&2
  else
    echo "Install docker-compose" >&2
    sudo apt install -y docker-compose
  fi

	echo "" >&2
	echo "You should now restart your system" >&2
}

function update_docker() {
	sudo apt upgrade docker docker-compose
}

function do_python3_checks() {
	VIRTUALENV_GOOD="false"
	if command_exists virtualenv; then
		VIRTUALENV_GOOD="true"
		echo "Python virtualenv found." >&2
	fi
	PYTHON_VERSION_GOOD="false"
	if command_exists $PYTHON_CMD; then
		PYTHON_VERSION=$($PYTHON_CMD --version 2>/dev/null)
		PYTHON_VERSION_MAJOR=$(echo "$PYTHON_VERSION"| cut -d' ' -f 2 | cut -d' ' -f 2 | cut -d'.' -f 1)
		PYTHON_VERSION_MINOR=$(echo "$PYTHON_VERSION"| cut -d' ' -f 2 | cut -d'.' -f 2)
		PYTHON_VERSION_BUILD=$(echo "$PYTHON_VERSION"| cut -d' ' -f 2 | cut -d'.' -f 3)

		printf "Python Version: '${PYTHON_VERSION:-Unknown}'. "
		if [ "$(minimum_version_check $REQ_PYTHON_VERSION $PYTHON_VERSION_MAJOR $PYTHON_VERSION_MINOR $PYTHON_VERSION_BUILD)" == "true" -a "$VIRTUALENV_GOOD" == "true" ]; then
			PYTHON_VERSION_GOOD="true"
			echo "Python and virtualenv is up to date." >&2
		else
			echo "Python is outdated or virtualenv is missing" >&2
			install_python3_and_deps "$PYTHON_VERSION_MAJOR.$PYTHON_VERSION_MINOR.$PYTHON_VERSION_BUILD" "$VIRTUALENV_GOOD"
			return 1
		fi
	else
		install_python3_and_deps
		return 1
	fi
}

function do_env_setup() {
	echo "Setting up environment:"
	if [[ ! "$(user_in_group bluetooth)" == "notgroup" ]] && [[ ! "$(user_in_group bluetooth)" == "true" ]]; then
    echo "User is NOT in 'bluetooth' group. Adding:" >&2
    echo "sudo usermod -G bluetooth -a $USER" >&2
		sudo usermod -G "bluetooth" -a $USER
	fi

	if [ ! "$(user_in_group docker)" == "true" ]; then
    echo "User is NOT in 'docker' group. Adding:" >&2
    echo "sudo usermod -G docker -a $USER" >&2
		sudo usermod -G "docker" -a $USER
	fi
}

function do_docker_checks() {
	if command_exists docker; then
		DOCKER_VERSION_GOOD="false"
		DOCKER_VERSION=$(docker version -f "{{.Server.Version}}")
		if [ ! -z "$DOCKER_VERSION" ]; then
			echo "Error getting docker version. Error when running docker command. Check that docker is installed correctly."
		fi
		DOCKER_VERSION_MAJOR=$(echo "$DOCKER_VERSION"| cut -d'.' -f 1)
		DOCKER_VERSION_MINOR=$(echo "$DOCKER_VERSION"| cut -d'.' -f 2)
		DOCKER_VERSION_BUILD=$(echo "$DOCKER_VERSION"| cut -d'.' -f 3)
		DOCKER_VERSION_BUILD=$(echo "$DOCKER_VERSION_BUILD"| cut -f1 -d"-")
		DOCKER_VERSION_BUILD=$(echo "$DOCKER_VERSION_BUILD"| cut -f1 -d"+")

		if [ "$(minimum_version_check $REQ_DOCKER_VERSION $DOCKER_VERSION_MAJOR $DOCKER_VERSION_MINOR $DOCKER_VERSION_BUILD )" == "true" ]; then
			[ -f .docker_outofdate ] && rm .docker_outofdate
			DOCKER_VERSION_GOOD="true"
			echo "Docker version $DOCKER_VERSION >= $REQ_DOCKER_VERSION. Docker is good to go." >&2
		else
      if [ "$NOASKCONFIRM" == "true" ]; then
        update_docker
      else
        if [ ! -f .docker_outofdate ]; then
          if (whiptail --title "Docker and Docker-Compose Version Issue" --yesno "Docker version is currently $DOCKER_VERSION which is less than $REQ_DOCKER_VERSION consider upgrading or you may experience issues. You will not be prompted again. You can manually upgrade by typing:\n  sudo apt upgrade docker docker-compose\n\nAttempt to upgrade now?" 20 78); then
            update_docker
          else
            touch .docker_outofdate
          fi
        fi
      fi
		fi
	else
		[ -f .docker_outofdate ] && rm .docker_outofdate
		echo "Docker not installed" >&2
    if [ "$NOASKCONFIRM" == "true" ]; then
      do_env_setup
      install_docker
    else
      if [ ! -f .docker_notinstalled ]; then
        if (whiptail --title "Docker and Docker-Compose" --yesno "Docker is not currently installed, and is required to run IOTstack. Would you like to install docker and docker-compose now?\nYou will not be prompted again." 20 78); then
            [ -f .docker_notinstalled ] && rm .docker_notinstalled
            do_env_setup
            install_docker
          else
            touch .docker_notinstalled
        fi
      fi
    fi
	fi
}

function do_env_checks() {
	GROUPSGOOD=0

	if [[ ! "$(user_in_group bluetooth)" == "notgroup" ]] && [[ ! "$(user_in_group bluetooth)" == "true" ]]; then
	  GROUPSGOOD=1
    echo "User is NOT in 'bluetooth' group" >&2
	fi

	if [[ ! "$(user_in_group docker)" == "true" ]]; then
	  GROUPSGOOD=1
    echo "User is NOT in 'docker' group" >&2
	fi

	if [ "$GROUPSGOOD" == 1 ]; then
		echo "!! You might experience issues with docker or bluetooth. To fix run: ./menu.sh --run-env-setup"
	fi
}

function do_kernel_checks() {
    if ! grep -q "cgroup_memory=1 cgroup_enable=memory" /boot/cmdline.txt; then
        echo "Kernel cgroups not enabled. Adding kernel parameters." >&2
        echo "You will need to restart your system before the changes take effect."
        echo $(cat /boot/cmdline.txt) cgroup_memory=1 cgroup_enable=memory | sudo tee /boot/cmdline.txt
    fi
}

touch .new_install
echo "Enter in the sudo password when prompted, to install dependencies"

sudo apt-get install git -y
git clone https://github.com/SensorsIot/IOTstack.git
cd IOTstack

if [ $? -eq 0 ]; then
  echo "IOTstack cloned"
=======
	# direct exit - not via handle_exit()
	exit 1
>>>>>>> 7a05f3262f18f9839ba267cdfee44f8c731ab445
else
	echo "pass"
fi


#----------------------------------------------------------------------
#					script memory (exit conditions)
#----------------------------------------------------------------------

function handle_exit() {

	# record the exit condition (if possible)
	[ -d "$IOTSTACK" ] && echo "$1" >"$IOTSTACK_INSTALLER_HINT"

	# inform the user
	echo -n "$SCRIPT completed"

	# reboot takes precedence over logout
	if [ "$REBOOT_REQUIRED" = "true" ] ; then
		echo " - a reboot is required."
		sleep 2
		sudo reboot
	elif [ "$LOGOUT_REQUIRED" = "true" ] ; then
		echo " - a logout is required."
		sleep 2
		kill -HUP "$PPID"
	fi

	# exit as instructed
	echo ""
	exit $1

}


#----------------------------------------------------------------------
#				IOTstack dependencies installed via apt
#----------------------------------------------------------------------

echo -e "\nUpdating Advanced Package Tool (apt) caches"
sudo apt update

echo -e "\nInstalling/updating IOTstack dependencies"
sudo apt install -y $APT_DEPENDENCIES


#----------------------------------------------------------------------
#						docker + compose installation
#----------------------------------------------------------------------

# is docker installed?
if [ -z $(which docker) ] ; then
	# no! use the convenience script
	echo -e "\nInstalling docker and docker-compose-plugin using the 'convenience script'"
	echo "from https://get.docker.com ..."
	curl -fsSL https://get.docker.com | sudo sh
	if [ $? -eq 0 ] ; then
		echo -e "\nInstallation of docker and docker-compose-plugin completed normally."
		REBOOT_REQUIRED=true
	else
		echo -e "\nThe 'convenience script' returned an error. Unable to proceed."
		handle_exit 1
	fi
else
	echo -e -n "\nDocker is already installed - checking your version - "
	DOCKER_VERSION_INSTALLED="$(docker version -f "{{.Server.Version}}")"
	if dpkg --compare-versions "$DOCKER_VERSION_MINIMUM" "gt" "$DOCKER_VERSION_INSTALLED" ; then
		echo "fail"
		echo "You have an obsolete version of Docker installed:"
		echo "      Minimum version required: $DOCKER_VERSION_MINIMUM"
		echo "   Version currently installed: $DOCKER_VERSION_INSTALLED"
		echo "Try updating your system by running:"
		echo "   \$ sudo apt update && sudo apt upgrade -y"
		echo "   \$ docker version -f {{.Server.Version}}"
		echo "If the version number changes, try re-running this script. If the"
		echo "version number does not change, you may need to uninstall both"
		echo "docker and docker-compose. If any containers are running, stop"
		echo "them, then run:"
		echo "   \$ sudo systemctl stop docker.service"
		echo "   \$ sudo systemctl disable docker.service"
		echo "   \$ sudo apt -y purge docker-ce docker-ce-cli containerd.io docker-compose"
		echo "   \$ sudo apt -y autoremove"
		echo "   \$ sudo reboot"
		echo "and then re-run this script after the reboot."
		handle_exit 1
	else
		echo "pass"
	fi
fi


#----------------------------------------------------------------------
#							group memberships
#----------------------------------------------------------------------

function should_add_user_to_group()
{
	# sense group does not exist
	grep -q "^$1:" /etc/group || return 1
	# sense group exists and user is already a member
	groups | grep -q "\b$1\b" && return 1
	# group exists, user should be added
	return 0
}

# check group membership
echo -e -n "\nChecking group memberships"
for GROUP in $DESIRED_GROUPS ; do
	echo -n " - $GROUP "
	if should_add_user_to_group $GROUP ; then
		echo -n "adding $USER"
		sudo /usr/sbin/usermod -G $GROUP -a $USER
		LOGOUT_REQUIRED=true
	else
		echo -n "pass"
	fi
done
echo ""

#----------------------------------------------------------------------
#					docker-compose setup/verification
#----------------------------------------------------------------------

# Correct installation of docker-compose is defined as the result of
# `which docker-compose` (typically $COMPOSE_SYMLINK_PATH) being a
# symlink pointing to the expected location of docker-compose-plugin as
# it is installed by the convenience script ($COMPOSE_PLUGIN_PATH).
# Alternatively, if `which docker-compose` returns null but the plugin
# is in the expected location, the necessary symlink can be created by
# this script and then docker-compose will be installed "correctly".

function is_running_OS_release() {
	unset VERSION_CODENAME
	[ -f "/etc/os-release" ] && eval $(grep "^VERSION_CODENAME=" /etc/os-release)
	[ "$VERSION_CODENAME" = "$1" ] && return 0
	return 1
}

function is_python_script() {
	[ $(file -b "$1" | grep -c "^Python script") -gt 0 ] && return 0
	return 1
}

# presume docker-compose not installed correctly
COMPOSE_INSTALLED_CORRECTLY=false

# search for docker-compose in the PATH
COMPOSE_CMD_PATH=$(which docker-compose)

# is docker-compose in the PATH?
echo -e -n "\nChecking whether docker-compose is installed correctly - "
if [ -n "$COMPOSE_CMD_PATH" ] ; then
	# yes! is it a symlink and does the symlink point to a file?
	if [ -L "$COMPOSE_CMD_PATH" -a -f "$COMPOSE_CMD_PATH" ] ; then
		# yes! fetch the inode of what the link points to
		COMPOSE_CMD_INODE=$(stat -c "%i" -L "$COMPOSE_CMD_PATH")
		# does the plugin exist at the expected path?
		if [ -f "$COMPOSE_PLUGIN_PATH" ] ; then
			# yes! fetch the plugin's inode
			COMPOSE_PLUGIN_INODE=$(stat -c "%i" "$COMPOSE_PLUGIN_PATH")
			# are the inodes the same?
			if [ $COMPOSE_CMD_INODE -eq $COMPOSE_PLUGIN_INODE ] ; then
				# yes! thus docker-compose is installed correctly
				COMPOSE_INSTALLED_CORRECTLY=true
			fi
		fi
	fi
else
	# no! does the plugin exist at the expected location?
	if [ -f "$COMPOSE_PLUGIN_PATH" ] ; then
		# yes! so, no command, but plugin present. Fix with symlink
		sudo ln -s "$COMPOSE_PLUGIN_PATH" "$COMPOSE_SYMLINK_PATH"
		# and now compose is installed correctly
		COMPOSE_INSTALLED_CORRECTLY=true
	else
		echo "fail"
		echo "Your system has docker installed but doesn't seem to have either"
		echo "docker-compose or docker-compose-plugin. Try running:"
		echo "   \$ sudo apt install -y docker-compose-plugin"
		echo "and then try re-running this script."
		handle_exit 1
	fi
fi

# is docker-compose installed correctly?
if [ "$COMPOSE_INSTALLED_CORRECTLY" = "true" ] ; then
	echo "pass"
	echo -e -n "\nChecking your version of docker-compose - "
	COMPOSE_VERSION_INSTALLED="$(docker-compose version --short)"
	if dpkg --compare-versions "$COMPOSE_VERSION_MINIMUM" "gt" "$COMPOSE_VERSION_INSTALLED" ; then
		echo "fail"
		echo "You have an obsolete version of docker-compose installed:"
		echo "      Minimum version required: $COMPOSE_VERSION_MINIMUM"
		echo "   Version currently installed: $COMPOSE_VERSION_INSTALLED"
		echo "Try updating your system by running:"
		echo "   \$ sudo apt update && sudo apt upgrade -y"
		echo "and then try re-running this script."
		handle_exit 1
	else
		echo "pass"
	fi
else
	echo "fail"
	echo "docker-compose is not installed correctly. The most common reason is"
	echo "having installed docker and docker-compose without using the official"
	echo "'convenience script'. You may be able to solve this problem by running"
	if is_python_script "$COMPOSE_CMD_PATH" ; then
		if is_running_OS_release bookworm ; then
			echo "   \$ pip3 uninstall -y --break-system-packages docker-compose"
			echo "   \$ sudo pip3 uninstall -y --break-system-packages docker-compose"
		else
			echo "   \$ pip3 uninstall -y docker-compose"
			echo "   \$ sudo pip3 uninstall -y docker-compose"
		fi
		echo "   (ignore any errors from those commands)"
	else
		echo "   \$ sudo apt purge -y docker-compose"
	fi
	echo "and then try re-running this script."
	handle_exit 1
fi


#----------------------------------------------------------------------
#							Clone IOTstack repo
#----------------------------------------------------------------------

# does the IOTstack folder already exist?
if [ ! -d "$IOTSTACK" ] ; then
	# no! clone from GitHub
	if [ -n "$GIT_CLONE_OPTIONS" ] ; then
		echo -e "\nCloning the IOTstack repository from GitHub using options $GIT_CLONE_OPTIONS"
		git clone "$GIT_CLONE_OPTIONS" https://github.com/SensorsIot/IOTstack.git "$IOTSTACK"
	else
		echo -e "\nCloning the full IOTstack repository from GitHub"
		git clone https://github.com/SensorsIot/IOTstack.git "$IOTSTACK"
	fi
	if [ $? -eq 0 -a -d "$IOTSTACK" ] ; then
		echo "IOTstack cloned successfully into $IOTSTACK"
		mkdir -p "$IOTSTACK/backups" "$IOTSTACK/services"
	else
		echo "Unable to clone IOTstack (likely a git or network error)"
		handle_exit 1
	fi
else
	echo -e "\n$IOTSTACK already exists - no need to clone from GitHub"
fi

# initialise docker-compose global environment file with system timezone
if [ ! -f "$IOTSTACK_ENV" ] || [ $(grep -c "^TZ=" "$IOTSTACK_ENV") -eq 0 ] ; then
	echo "TZ=$(cat /etc/timezone)" >>"$IOTSTACK_ENV"
fi

#----------------------------------------------------------------------
#								Python support
#----------------------------------------------------------------------

# make sure "python" invokes "python3"
PYTHON_INVOKES=$(update-alternatives --list python 2>/dev/null)
PYTHON3_PATH=$(which python3)
if [ "$PYTHON_INVOKES" != "$PYTHON3_PATH" ] ; then
	echo -e "\nMaking python3 the default"
	sudo update-alternatives --install /usr/bin/python python "$PYTHON3_PATH" 1
fi

echo -e -n "\nChecking your version of Python - "
PYTHON_VERSION_INSTALLED="$(python --version)"
PYTHON_VERSION_INSTALLED="${PYTHON_VERSION_INSTALLED#*Python }"
if dpkg --compare-versions "$PYTHON_VERSION_MINIMUM" "gt" "$PYTHON_VERSION_INSTALLED" ; then
	echo "fail"
	echo "You have an obsolete version of python installed:"
	echo "      Minimum version required: $PYTHON_VERSION_MINIMUM"
	echo "   Version currently installed: $PYTHON_VERSION_INSTALLED"
	echo "Try updating your system by running:"
	echo "   \$ sudo apt update && sudo apt upgrade -y"
	echo "   \$ python --version"
	echo "If the version number changes, try re-running this script. If not, you"
	echo "may need to reinstall python3-pip, python3-dev and python3-virtualenv."
	handle_exit 1
else
	echo "pass"
fi

# implement menu requirements
if [ -e "$IOTSTACK_MENU_REQUIREMENTS" ] ; then
	echo -e "\nChecking and updating IOTstack dependencies (pip)" 
	unset PYTHON_OPTIONS
	if is_running_OS_release bookworm ; then
		echo "Note: pip3 installs bypass externally-managed environment check"
		PYTHON_OPTIONS="--break-system-packages"
	fi
	pip3 install -U $PYTHON_OPTIONS -r "$IOTSTACK_MENU_REQUIREMENTS"
fi

# trigger re-creation of venv on next menu launch. Strictly speaking,
# sudo is not required for this but it protects against accidental prior
# use of sudo when the venv was created
sudo rm -rf "$IOTSTACK_MENU_VENV_DIR"


#----------------------------------------------------------------------
#						Raspberry Pi boot options
#----------------------------------------------------------------------

# set cmdline options (if possible - Raspberry Pi dependency)
TARGET="/boot/cmdline.txt"
if [ -e "$TARGET" ] ; then
	echo -e -n "\nChecking Raspberry Pi boot-time options - "
	unset APPEND
	for OPTION in $CMDLINE_OPTIONS ; do
		if [ $(grep -c "$OPTION" "$TARGET") -eq 0 ] ; then
			APPEND="$APPEND $OPTION"
		fi
	done
	if [ -n "$APPEND" ] ; then
		echo "appending$APPEND"
		sudo sed -i.bak "s/$/$APPEND/" "$TARGET"
		REBOOT_REQUIRED=true
	else
		echo "no modifications needed"
	fi
fi


#----------------------------------------------------------------------
#							normal exit
#----------------------------------------------------------------------

handle_exit 0
