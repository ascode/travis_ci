#!/bin/bash
#
# ownCloud
#
# @author Thomas Müller
# @copyright 2014 Thomas Müller thomas.mueller@tmit.eu
#

set -e

DATABASENAME=oc_autotest
DATABASEUSER=oc_autotest
ADMINLOGIN=admin
BASEDIR=$PWD

DBCONFIGS="sqlite mysql pgsql oracle"
PHPUNIT=$(which phpunit)

# set oracle home if it is not set
TRAVIS_ORACLE_HOME="/usr/lib/oracle/xe/app/oracle/product/10.2.0/server"
[ -z "$ORACLE_HOME" ] && ORACLE_HOME=$TRAVIS_ORACLE_HOME

if [ $1 ]; then
	FOUND=0
	for DBCONFIG in $DBCONFIGS; do
		if [ $1 = $DBCONFIG ]; then
			FOUND=1
			break
		fi
	done
	if [ $FOUND = 0 ]; then
		echo -e "Unknown database config name \"$1\"\n" >&2
		print_syntax
		exit 2
	fi
fi

# use tmpfs for datadir - should speedup unit test execution
DATADIR=$BASEDIR/data-autotest

echo "Using database $DATABASENAME"

# create autoconfig for sqlite, mysql and postgresql
cat > ./tests/autoconfig-sqlite.php <<DELIM
<?php
\$AUTOCONFIG = array (
  'installed' => false,
  'dbtype' => 'sqlite',
  'dbtableprefix' => 'oc_',
  'adminlogin' => '$ADMINLOGIN',
  'adminpass' => 'admin',
  'directory' => '$DATADIR',
);
DELIM

cat > ./tests/autoconfig-mysql.php <<DELIM
<?php
\$AUTOCONFIG = array (
  'installed' => false,
  'dbtype' => 'mysql',
  'dbtableprefix' => 'oc_',
  'adminlogin' => '$ADMINLOGIN',
  'adminpass' => 'admin',
  'directory' => '$DATADIR',
  'dbuser' => '$DATABASEUSER',
  'dbname' => '$DATABASENAME',
  'dbhost' => 'localhost',
  'dbpass' => 'owncloud',
);
DELIM

cat > ./tests/autoconfig-pgsql.php <<DELIM
<?php
\$AUTOCONFIG = array (
  'installed' => false,
  'dbtype' => 'pgsql',
  'dbtableprefix' => 'oc_',
  'adminlogin' => '$ADMINLOGIN',
  'adminpass' => 'admin',
  'directory' => '$DATADIR',
  'dbuser' => '$DATABASEUSER',
  'dbname' => '$DATABASENAME',
  'dbhost' => 'localhost',
  'dbpass' => '',
);
DELIM

cat > ./tests/autoconfig-oracle.php <<DELIM
<?php
\$AUTOCONFIG = array (
  'installed' => false,
  'dbtype' => 'oci',
  'dbtableprefix' => 'oc_',
  'adminlogin' => '$ADMINLOGIN',
  'adminpass' => 'admin',
  'directory' => '$DATADIR',
  'dbuser' => 'autotest',
  'dbname' => 'XE',
  'dbhost' =>'$DATABASEHOST',
  'dbpass' => 'owncloud',
  'loglevel' => 0,
);
DELIM

more ./tests/autoconfig-oracle.php

function execute_tests {
	echo "Setup environment for $1 testing ..."
	# back to root folder
	cd $BASEDIR

	# revert changes to tests/data
	git checkout tests/data/*

	# reset data directory
	rm -rf $DATADIR
	mkdir $DATADIR

	cp tests/preseed-config.php config/config.php

	# copy autoconfig
	cp $BASEDIR/tests/autoconfig-$1.php $BASEDIR/config/autoconfig.php

	# trigger installation
	echo "INDEX"
	php -f index.php
	echo "END INDEX"

	#test execution
	cd tests
	#php -f enable_all.php
}

#
# start test execution
#
if [ -z "$1" ]
  then
	# run all known database configs
	for DBCONFIG in $DBCONFIGS; do
		execute_tests $DBCONFIG
	done
else
	execute_tests $1 $2 $3
fi

# show environment


echo "owncloud configuration:"
cat $BASEDIR/config/config.php


echo "data directory:"
ls -ll $DATADIR

echo "owncloud.log:"
[ -f "$DATADIR/owncloud.log" ] && cat $DATADIR/owncloud.log
[ -f "$BASEDIR/data/owncloud.log" ] && cat $BASEDIR/data/owncloud.log

cd $BASEDIR

