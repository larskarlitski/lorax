#!/bin/bash
# Note: execute this file from the project root directory

set -e

. /usr/share/beakerlib/beakerlib.sh
. $(dirname $0)/lib/lib.sh

CLI="${CLI:-./src/bin/composer-cli}"


rlJournalStart
    rlPhaseStartTest "compose types"
        TYPE_LIVE_ISO="live-iso"
        TYPE_ALIBABA="alibaba"
        TYPE_GOOGLE="google"

        # backend specific compose type overrides
        if [ "$BACKEND" == "osbuild-composer" ]; then
            TYPE_LIVE_ISO=""
            TYPE_ALIBABA=""
            TYPE_GOOGLE=""
        fi

        # arch specific compose type selections
        if [ "$(uname -m)" = "x86_64" ]; then
            SUPPORTED_TYPES="$TYPE_ALIBABA ami ext4-filesystem $TYPE_GOOGLE $TYPE_LIVE_ISO openstack partitioned-disk qcow2 tar vhd vmdk"
        else
            SUPPORTED_TYPES="ext4-filesystem $TYPE_LIVE_ISO openstack partitioned-disk qcow2 tar"
        fi

        # truncate white space in case some types are not available
        SUPPORTED_TYPES=$(echo "$SUPPORTED_TYPES" | tr -s ' ' | sed 's/^[[:space:]]*//')
        rlAssertEquals "lists all supported types" "`$CLI compose types | xargs`" "$SUPPORTED_TYPES"
    rlPhaseEnd

    rlPhaseStartTest "compose start"
        UUID=`$CLI --test=2 compose start example-http-server tar`
        rlAssertEquals "exit code should be zero" $? 0

        UUID=`echo $UUID | cut -f 2 -d' '`
    rlPhaseEnd

    rlPhaseStartTest "compose info"
        if [ -n "$UUID" ]; then
            rlRun -t -c "$CLI compose info $UUID | egrep 'RUNNING|WAITING'"
        else
            rlFail "Compose UUID is empty!"
        fi
    rlPhaseEnd

    rlPhaseStartTest "compose image"
        wait_for_compose $UUID
        if [ -n "$UUID" ]; then
            check_compose_status "$UUID"

            rlRun -t -c "$CLI compose image $UUID"
            rlAssertExists "$UUID-root.tar.xz"

            # because this path is listed in the documentation
            rlAssertExists    "/var/lib/lorax/composer/results/$UUID/"
            rlAssertExists    "/var/lib/lorax/composer/results/$UUID/root.tar.xz"
            rlAssertNotDiffer "/var/lib/lorax/composer/results/$UUID/root.tar.xz" "$UUID-root.tar.xz"
        fi
    rlPhaseEnd

rlJournalEnd
rlJournalPrintText
