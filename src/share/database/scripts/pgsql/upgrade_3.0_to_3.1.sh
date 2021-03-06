#!/bin/sh

# Include utilities. Use installed version if available and
# use build version if it isn't.
if [ -e ${prefix}/share/kea/scripts/admin-utils.sh ]; then
    . ${prefix}/share/kea/scripts/admin-utils.sh
else
    . /home/wlodek/dev/kea/src/bin/admin/admin-utils.sh
fi

VERSION=`pgsql_version "$@"`

if [ "$VERSION" != "3.0" ]; then
    printf "This script upgrades 3.0 to 3.1. Reported version is $VERSION. Skipping upgrade.\n"
    exit 0
fi

psql "$@" >/dev/null <<EOF

START TRANSACTION;

-- Upgrade to schema 3.1 begins here:

-- The 'client-id' host identifier type was missing in the
-- 2.0 -> 3.0 upgrade script. However, it was present in the
-- dhcpdb_create.pgsql file. This means that this entry may
-- or may not be present. By the conditional insert below we
-- will only insert it if it doesn't exist.
INSERT INTO host_identifier_type (type, name)
  SELECT 3, 'client-id'
    WHERE NOT EXISTS (
        SELECT type FROM host_identifier_type WHERE type = 3
    );

-- We also add a new identifier type: flex-id.
INSERT INTO host_identifier_type VALUES (4, 'flex-id');

-- Set 3.1 schema version.
UPDATE schema_version
    SET version = '3', minor = '1';

-- Schema 3.1 specification ends here.

-- Commit the script transaction
COMMIT;

EOF

exit $RESULT

