#!/bin/bash
set -e

export USER=${USER:=ubuntu}
export JOBS=${JOBS:=$(nproc)}
export PGBIN="$(pg_config --bindir)"
export RAILS_ENV=test
export CI=true
export OPENPROJECT_DISABLE_DEV_ASSET_PROXY=1
export CAPYBARA_DYNAMIC_HOSTNAME=0
export CAPYBARA_DOWNLOADED_FILE_DIR=${CAPYBARA_DOWNLOADED_FILE_DIR:="/tmp"}
# for parallel rspec
export PARALLEL_TEST_PROCESSORS=$JOBS
#echo "create database app; create user app with superuser encrypted password 'p4ssw0rd'; grant all privileges on database app to app;" | sudo su - postgres -c psql
export DATABASE_URL=${DATABASE_URL:="postgres://app:p4ssw0rd@127.0.0.1/app"}
CHROME_SOURCE_URL=https://dl.google.com/dl/linux/direct/google-chrome-stable_current_amd64.deb

#su - postgres -c "$PGBIN/initdb -E UTF8 -D /tmp/nulldb"
#su - postgres -c "$PGBIN/pg_ctl -D /tmp/nulldb -l /dev/null -w start"
#echo "create database app; create user app with superuser encrypted password 'p4ssw0rd'; grant all privileges on database app to app;" | sudo su - postgres -c psql

cp docker/ci/database.yml config/

execute() {
	if [ $(id -u) -eq 0 ]; then
		su $USER -c "$@"
	else
		bash -c "$@"
	fi
}


if [ "$1" == "setup" ]; then
	echo "Preparing environment for running tests..."
	shift

	for i in $(seq 0 $JOBS); do
		folder="$CAPYBARA_DOWNLOADED_FILE_DIR/$i"
		echo "Creating folder $folder..."
		rm -rf "$folder"
		mkdir -p "$folder"
		chmod 1777 "$folder"
	done

	execute "time bundle install -j$JOBS"
	execute "TEST_ENV_NUMBER=0 time bash ./script/ci/cache_prepare.sh"
	execute "time bundle exec rake parallel:setup"
fi

if [ "$1" == "setup-system" ]; then
	echo "Downloading and installing required browsers..."
	shift
	execute "sudo apt install -y imagemagick default-jre-headless postgresql libpq-dev"
	execute "wget --no-verbose -O /tmp/$(basename $CHROME_SOURCE_URL) $CHROME_SOURCE_URL && \
		  sudo apt install -y /tmp/$(basename $CHROME_SOURCE_URL) && rm -f /tmp/$(basename $CHROME_SOURCE_URL)"
fi

if [ "$1" == "run-units" ]; then
	shift
	execute "time bundle exec rake parallel:units"
fi

if [ "$1" == "run-features" ]; then
	shift
	execute "time bundle exec rake parallel:features"
fi

exec "$@"
