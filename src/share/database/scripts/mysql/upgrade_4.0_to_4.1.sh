#!/bin/sh

# Include utilities. Use installed version if available and
# use build version if it isn't.
if [ -e ${prefix}/share/kea/scripts/admin-utils.sh ]; then
    . ${prefix}/share/kea/scripts/admin-utils.sh
else
    . /home/wlodek/dev/kea/src/bin/admin/admin-utils.sh
fi

VERSION=`mysql_version "$@"`

if [ "$VERSION" != "4.0" ]; then
    printf "This script upgrades 4.0 to 4.1. Reported version is $VERSION. Skipping upgrade.\n"
    exit 0
fi

mysql "$@" <<EOF

# In the event hardware address cannot be determined, we need to satisfy
# foreign key constraint between lease6 and lease_hardware_source
INSERT INTO lease_hwaddr_source VALUES (0, 'HWADDR_SOURCE_UNKNOWN');

#
# Add order by lease address to lease4DumpData 
#
DROP PROCEDURE IF EXISTS lease4DumpData;
DELIMITER $$
CREATE PROCEDURE lease4DumpData()
BEGIN
SELECT
    INET_NTOA(l.address),
    IFNULL(HEX(l.hwaddr), ''),
    IFNULL(HEX(l.client_id), ''),
    l.valid_lifetime,
    l.expire,
    l.subnet_id,
    l.fqdn_fwd,
    l.fqdn_rev,
    l.hostname,
    s.name
FROM
    lease4 l
    LEFT OUTER JOIN lease_state s on (l.state = s.state)
ORDER BY l.address;
END $$
DELIMITER ;

#
# Add order by lease address to lease6DumpData 
#
DROP PROCEDURE IF EXISTS lease6DumpData;
DELIMITER $$
CREATE PROCEDURE lease6DumpData()
BEGIN
SELECT
    l.address,
    IFNULL(HEX(l.duid), ''),
    l.valid_lifetime,
    l.expire,
    l.subnet_id,
    l.pref_lifetime,
    IFNULL(t.name, ''),
    l.iaid,
    l.prefix_len,
    l.fqdn_fwd,
    l.fqdn_rev,
    l.hostname,
    IFNULL(HEX(l.hwaddr), ''),
    IFNULL(l.hwtype, ''),
    IFNULL(h.name, ''),
    IFNULL(s.name, '')
FROM lease6 l
    left outer join lease6_types t on (l.lease_type = t.lease_type)
    left outer join lease_state s on (l.state = s.state)
    left outer join lease_hwaddr_source h on (l.hwaddr_source = h.hwaddr_source)
ORDER BY l.address;
END $$
DELIMITER ;

# Update the schema version number
UPDATE schema_version
SET version = '4', minor = '1';
# This line concludes database upgrade to version 4.1.

EOF

RESULT=$?

exit $?
