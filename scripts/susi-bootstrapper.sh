#!/bin/bash

SUSI_BINARY_PATH=/home/tino/Code/susi/bin
CONTAINER_NAME="susi-test"

function bootstrap_debian {
    debootstrap \
        --arch amd64 \
        --include dbus \
        jessie \
        /var/lib/machines/jessie \
        http://ftp.debian.de/debian
    if [ $? != 0 ]; then
        echo "can not bootstrap debian jessie, is your internet connection broken?"
        exit 1
    fi
}

function create_new_container {
    CONTAINER=$1
    if [ ! -d /var/lib/machines/jessie ]; then
        echo "no debian jessie found, try to bootstrap one."
        bootstrap_debian
    fi
    cp -rf /var/lib/machines/jessie /var/lib/machines/$CONTAINER
    echo $CONTAINER > /var/lib/machines/$CONTAINER/etc/hostname
}

function install_binary_to_container {
    BINARY=$1
    CONTAINER=$2
    echo "installing $BINARY to $CONTAINER..."
    cp $BINARY /var/lib/machines/$CONTAINER/bin/
    if [ $? != 0 ]; then
        echo "error while copy binary, did you already build susi or is your container image malformed? "
        exit 1
    fi
    for lib in $(ldd $BINARY | cut -d ' ' -f3); do
        cp $lib /var/lib/machines/$CONTAINER/lib/
        if [ $? != 0 ]; then
            echo "error while copy library, did you already build susi?"
            exit 1
        fi
    done
}

function create_keys {
    ID=$1
    CONTAINER=$2
    echo "generating keys for $ID..."
    KEY=$(printf "%s_key.pem" $ID)
    CERT=$(printf "%s_cert.pem" $ID)
    mkdir -p /var/lib/machines/$CONTAINER/etc/susi/keys
    openssl req -batch -nodes -x509 -newkey rsa:2048 -days 36500\
        -keyout /var/lib/machines/$CONTAINER/etc/susi/keys/$KEY \
        -out /var/lib/machines/$CONTAINER/etc/susi/keys/$CERT 2>/dev/null
}

function install_initd_script {
    NAME=$1
    DEPS=$2
    CONTAINER=$3
    CMD=$4
    template=$(cat unitfile.template)
    script=${template//__NAME__/$NAME}
    script=${script//__CMD__/$CMD}
    script=${script//__DEPS__/$DEPS}
    echo "$script" > /var/lib/machines/$CONTAINER/etc/systemd/system/$NAME.service
    ln -s /var/lib/machines/$CONTAINER/etc/systemd/system/$NAME.service /var/lib/machines/$CONTAINER/etc/systemd/system/multi-user.target.wants/$NAME.service
}

function setup_core {
    CONTAINER=$1
    install_binary_to_container $SUSI_BINARY_PATH/susi-core $CONTAINER
    create_keys susi-core $CONTAINER
    install_initd_script susi-core "" $CONTAINER "/bin/susi-core -k /etc/susi/keys/susi-core_key.pem -c /etc/susi/keys/susi-core_cert.pem"
}

function setup_component {
    CONTAINER=$1
    COMPONENT=$2
    install_binary_to_container $SUSI_BINARY_PATH/$COMPONENT $CONTAINER
    create_keys $COMPONENT $CONTAINER
    defaultConfig=$(printf "default_%s_config.json" $(echo $COMPONENT|cut -d- -f2))
    targetConfig=$(echo $defaultConfig|cut -d_ -f2,3,4)
    cp $defaultConfig /var/lib/machines/$CONTAINER/etc/susi/$targetConfig
    install_initd_script $COMPONENT "susi-core.service" $CONTAINER "/bin/$COMPONENT -c /etc/susi/$targetConfig"
}

function ask_and_install {
    BINARY=$1
    read -p "Do you wish to install $BINARY? [Y/n]" yn
    #cmd=$(printf "setup_%s" $(echo $BINARY|cut -d'-' -f2))
    case $yn in
        [Nn]* ) ;;
        * ) setup_component $CONTAINER_NAME $BINARY;;
    esac
}

read -p "Tell me the name of your project! " CONTAINER_NAME

echo "deleting old project $CONTAINER_NAME..."
rm -rf /var/lib/machines/$CONTAINER_NAME

echo "create new container from debian jessie..."
create_new_container $CONTAINER_NAME

read -p "Tell me where your susi binaries are located! [/home/tino/Code/susi/susi/bin]" SUSI_BINARY_PATH
if [ x"$SUSI_BINARY_PATH" = x"" ];then
    SUSI_BINARY_PATH=/home/tino/Code/susi/susi/bin
fi

setup_core $CONTAINER_NAME

ask_and_install susi-authenticator
ask_and_install susi-cluster
ask_and_install susi-duktape
ask_and_install susi-heartbeat
ask_and_install susi-leveldb
ask_and_install susi-mqtt
ask_and_install susi-serial
ask_and_install susi-udpserver
ask_and_install susi-webhooks
ask_and_install susi-statefile
ask_and_install susi-shell

echo "your container is now ready to use! you can start it with susi-starter.sh $CONTAINER_NAME"

exit 0
